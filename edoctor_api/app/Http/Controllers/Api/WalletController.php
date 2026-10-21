<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hospital;
use App\Models\PayoutRequest;
use App\Models\Pharmacy;
use App\Models\Wallet;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WalletController extends Controller
{
    /**
     * Récupère le portefeuille actif de l'utilisateur ou de sa structure médicale/officine.
     */
    protected function resolveWallet(Request $request): ?Wallet
    {
        $user = $request->user();
        if (!$user) {
            return null;
        }

        // 1. Pharmacien -> Portefeuille de son officine
        if ($user->isPharmacist()) {
            $pharmacy = Pharmacy::where('owner_id', $user->id)->first();
            return $pharmacy ? $pharmacy->getOrCreateWallet() : $user->getOrCreateWallet();
        }

        // 2. Administrateur Hospitalier -> Portefeuille de l'Hôpital
        if ($user->isHospitalAdmin() && $user->hospital_id) {
            $hospital = Hospital::find($user->hospital_id);
            return $hospital ? $hospital->getOrCreateWallet() : $user->getOrCreateWallet();
        }

        // 3. Médecin -> Portefeuille de son Hôpital de rattachement ou portefeuille personnel
        if ($user->isDoctor()) {
            if ($user->hospital_id) {
                $hospital = Hospital::find($user->hospital_id);
                if ($hospital) {
                    return $hospital->getOrCreateWallet();
                }
            }
            return $user->getOrCreateWallet();
        }

        // 4. Par défaut : Portefeuille personnel de l'utilisateur
        return $user->getOrCreateWallet();
    }

    /**
     * GET /api/wallet/my-wallet
     * Affiche l'état du portefeuille (solde disponible, séquestre, coordonnées de retrait).
     */
    public function show(Request $request): JsonResponse
    {
        $wallet = $this->resolveWallet($request);
        if (!$wallet) {
            return response()->json(['message' => 'Portefeuille introuvable.'], 404);
        }

        $user = $request->user();
        $stats = [];

        // Si praticien, ajouter ses performances personnelles
        if ($user->isDoctor()) {
            $consultationsCount = DB::table('consultations')
                ->where('doctor_id', $user->id)
                ->where('status', 'terminee')
                ->where('payment_status', 'paye')
                ->count();

            $totalGenerated = DB::table('consultations')
                ->where('doctor_id', $user->id)
                ->where('status', 'terminee')
                ->where('payment_status', 'paye')
                ->sum('consultation_fee');

            $stats['personal_doctor_consultations'] = $consultationsCount;
            $stats['personal_doctor_revenue'] = (float) $totalGenerated;
        }

        return response()->json([
            'success' => true,
            'wallet' => [
                'id' => $wallet->id,
                'holder_type' => class_basename($wallet->holder_type),
                'holder_id' => $wallet->holder_id,
                'balance' => (float) $wallet->balance,
                'pending_balance' => (float) $wallet->pending_balance,
                'total_balance' => (float) ($wallet->balance + $wallet->pending_balance),
                'currency' => $wallet->currency,
                'payout_channel' => $wallet->payout_channel,
                'payout_account' => $wallet->payout_account,
                'payout_account_name' => $wallet->payout_account_name,
                'is_active' => $wallet->is_active,
            ],
            'stats' => $stats,
            'recent_transactions' => $wallet->transactions()->limit(5)->get(),
        ]);
    }

    /**
     * GET /api/wallet/transactions
     * Historique paginé des transactions du portefeuille.
     */
    public function transactions(Request $request): JsonResponse
    {
        $wallet = $this->resolveWallet($request);
        if (!$wallet) {
            return response()->json(['message' => 'Portefeuille introuvable.'], 404);
        }

        $query = $wallet->transactions();

        if ($request->filled('type')) {
            $query->where('type', $request->string('type')->toString());
        }

        if ($request->filled('source_type')) {
            $query->where('source_type', $request->string('source_type')->toString());
        }

        $perPage = min(50, max(5, (int) $request->input('per_page', 15)));
        $transactions = $query->paginate($perPage);

        return response()->json($transactions);
    }

    /**
     * POST /api/wallet/payout-request
     * Soumet une demande de virement (T-Money, Flooz, Virement bancaire).
     */
    public function requestPayout(Request $request): JsonResponse
    {
        $wallet = $this->resolveWallet($request);
        if (!$wallet) {
            return response()->json(['message' => 'Portefeuille introuvable.'], 404);
        }

        $minPayout = (float) config('monetization.payout.min_amount', 2000.0);

        $validated = $request->validate([
            'amount' => ['required', 'numeric', "min:{$minPayout}"],
            'payout_method' => ['required', 'string', 'in:t-money,flooz,virement_bancaire'],
            'account_number' => ['required', 'string', 'max:50'],
            'account_name' => ['nullable', 'string', 'max:100'],
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        $amount = (float) $validated['amount'];
        if ((float) $wallet->balance < $amount) {
            return response()->json([
                'success' => false,
                'message' => "Solde disponible insuffisant. Vous disposez de {$wallet->balance} {$wallet->currency}.",
            ], 422);
        }

        try {
            $payout = DB::transaction(function () use ($wallet, $amount, $validated) {
                // 1. Débit immédiat du solde disponible du portefeuille
                $wallet->debit(
                    $amount,
                    "Demande de retrait vers {$validated['payout_method']} ({$validated['account_number']})",
                    'payout'
                );

                // 2. Enregistrement de la demande de reversement
                return $wallet->payoutRequests()->create([
                    'amount' => $amount,
                    'fee' => 0.00,
                    'net_amount' => $amount,
                    'payout_method' => $validated['payout_method'],
                    'account_number' => $validated['account_number'],
                    'account_name' => $validated['account_name'] ?? null,
                    'status' => 'en_attente',
                    'notes' => $validated['notes'] ?? null,
                ]);
            });

            return response()->json([
                'success' => true,
                'message' => 'Votre demande de reversement a été enregistrée avec succès. Le virement sera exécuté sous peu.',
                'payout_request' => $payout,
                'new_balance' => (float) $wallet->fresh()->balance,
            ], 201);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Erreur lors du traitement du retrait : ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * PUT /api/wallet/payout-account
     * Met à jour les coordonnées de paiement par défaut du portefeuille.
     */
    public function updatePayoutAccount(Request $request): JsonResponse
    {
        $wallet = $this->resolveWallet($request);
        if (!$wallet) {
            return response()->json(['message' => 'Portefeuille introuvable.'], 404);
        }

        $validated = $request->validate([
            'payout_channel' => ['required', 'string', 'in:t-money,flooz,virement_bancaire'],
            'payout_account' => ['required', 'string', 'max:50'],
            'payout_account_name' => ['nullable', 'string', 'max:100'],
        ]);

        $wallet->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Coordonnées de versement mises à jour avec succès.',
            'wallet' => $wallet->fresh(),
        ]);
    }
}
