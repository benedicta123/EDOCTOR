<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\Order;
use App\Models\Payment;
use App\Models\PayoutRequest;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminWalletController extends Controller
{
    /**
     * GET /api/admin/wallets
     * Liste consolidée de tous les portefeuilles de l'écosystème eDoctor.
     */
    public function indexWallets(Request $request): JsonResponse
    {
        abort_unless($request->user()?->isAdmin(), 403, "Accès réservé exclusivement aux administrateurs autorisés.");

        $wallets = Wallet::with('holder')->latest()->get()->map(function ($w) {
            return [
                'id' => $w->id,
                'holder_type' => class_basename($w->holder_type),
                'holder_id' => $w->holder_id,
                'holder_name' => $w->holder?->name ?? 'Partenaire',
                'balance' => (float) $w->balance,
                'pending_balance' => (float) $w->pending_balance,
                'currency' => $w->currency,
                'payout_channel' => $w->payout_channel,
                'payout_account' => $w->payout_account,
                'payout_account_name' => $w->payout_account_name,
                'is_active' => $w->is_active,
                'created_at' => $w->created_at,
            ];
        });

        $totalAvailable = Wallet::sum('balance');
        $totalPending = Wallet::sum('pending_balance');

        // Calcul des revenus nets plateforme eDoctor (commissions consultations, recherche officines, livraisons)
        $paymentsEdoctorFee = (float) Payment::where('status', 'completed')->sum('edoctor_fee');
        $consultationsEdoctorFee = (float) Consultation::whereIn('status', ['terminee', 'en_cours'])->where('payment_status', 'paye')->sum('edoctor_fee');
        if ($consultationsEdoctorFee <= 0) {
            $consultationsEdoctorFee = (float) Consultation::where('status', 'terminee')->sum('edoctor_fee');
        }
        $ordersEdoctorFee = (float) Order::whereIn('status', ['terminee', 'recuperee', 'en_livraison', 'prete'])->sum('edoctor_fee');
        $totalEdoctorRevenue = max($paymentsEdoctorFee, ($consultationsEdoctorFee + $ordersEdoctorFee));

        return response()->json([
            'success' => true,
            'summary' => [
                'total_available_balance' => (float) $totalAvailable,
                'total_escrow_pending_balance' => (float) $totalPending,
                'total_ecosystem_balance' => (float) ($totalAvailable + $totalPending),
                'wallets_count' => $wallets->count(),
                'total_edoctor_revenue' => (float) $totalEdoctorRevenue,
            ],
            'wallets' => $wallets,
        ]);
    }

    /**
     * GET /api/admin/payout-requests
     * Liste des demandes de reversement avec filtres de statut.
     */
    public function indexPayouts(Request $request): JsonResponse
    {
        abort_unless($request->user()?->isAdmin(), 403, "Accès réservé exclusivement aux administrateurs autorisés.");

        $query = PayoutRequest::with(['wallet.holder', 'processor:id,name,email'])->latest();

        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }

        $perPage = min(50, max(5, (int) $request->input('per_page', 20)));
        return response()->json($query->paginate($perPage));
    }

    /**
     * POST /api/admin/payout-requests/{payoutRequest}/approve
     * Approuve et marque comme exécuté un reversement Mobile Money ou Bancaire.
     */
    public function approvePayout(Request $request, PayoutRequest $payoutRequest): JsonResponse
    {
        abort_unless($request->user()?->isAdmin(), 403, "Accès réservé exclusivement aux administrateurs autorisés.");

        if ($payoutRequest->status === 'traite') {
            return response()->json(['message' => 'Cette demande de reversement a déjà été traitée.'], 422);
        }

        $validated = $request->validate([
            'transaction_ref' => ['nullable', 'string', 'max:100'],
            'notes' => ['nullable', 'string', 'max:500'],
        ]);

        $admin = $request->user();

        $payoutRequest->update([
            'status' => 'traite',
            'transaction_ref' => $validated['transaction_ref'] ?? ('PAYOUT-' . strtoupper(bin2hex(random_bytes(4)))),
            'notes' => $validated['notes'] ?? $payoutRequest->notes,
            'processed_by' => $admin->id,
            'processed_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Le reversement a été validé et marqué comme exécuté avec succès.',
            'payout_request' => $payoutRequest->load(['wallet.holder', 'processor:id,name']),
        ]);
    }

    /**
     * POST /api/admin/payout-requests/{payoutRequest}/reject
     * Rejette la demande de retrait et recrédite immédiatement le portefeuille du partenaire.
     */
    public function rejectPayout(Request $request, PayoutRequest $payoutRequest): JsonResponse
    {
        abort_unless($request->user()?->isAdmin(), 403, "Accès réservé exclusivement aux administrateurs autorisés.");

        if ($payoutRequest->status !== 'en_attente') {
            return response()->json(['message' => 'Seules les demandes en attente peuvent être rejetées.'], 422);
        }

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $admin = $request->user();

        DB::transaction(function () use ($payoutRequest, $validated, $admin) {
            // 1. Recréditer le solde disponible du portefeuille
            $wallet = $payoutRequest->wallet;
            if ($wallet) {
                $wallet->credit(
                    (float) $payoutRequest->amount,
                    "Restitution de solde suite au rejet du retrait #{$payoutRequest->id} : {$validated['reason']}",
                    'refund',
                    $payoutRequest->id
                );
            }

            // 2. Mettre à jour le statut
            $payoutRequest->update([
                'status' => 'rejete',
                'notes' => $validated['reason'],
                'processed_by' => $admin->id,
                'processed_at' => now(),
            ]);
        });

        return response()->json([
            'success' => true,
            'message' => 'La demande de retrait a été rejetée et les fonds ont été restitués au partenaire.',
            'payout_request' => $payoutRequest->fresh(['wallet']),
        ]);
    }

    /**
     * GET /api/admin/transactions
     * Historique global consolidé de toutes les transactions du système :
     * - Mouvements du livre-journal des portefeuilles (WalletTransaction : crédits, séquestres, libérations, parts livreurs, retraits)
     * - Paiements Mobile Money / FedaPay des patients (Payment : consultations et commandes pharmacies)
     */
    public function indexTransactions(Request $request): JsonResponse
    {
        abort_unless($request->user()?->isAdmin(), 403, "Accès réservé exclusivement aux administrateurs autorisés.");

        // 1. Mouvements des portefeuilles partenaires
        $walletTxs = WalletTransaction::with('wallet.holder')
            ->latest()
            ->limit(150)
            ->get()
            ->map(function (WalletTransaction $tx) {
                $wallet = $tx->wallet;
                $holderType = $wallet ? class_basename($wallet->holder_type) : 'Partner';
                $holderName = $wallet?->holder?->name ?? 'Partenaire eDoctor';
                $meta = is_array($tx->metadata) ? $tx->metadata : [];
                $isCourier = $tx->source_type === 'delivery';

                $category = match (true) {
                    $isCourier => 'courier_share',
                    $tx->type === 'hold' => 'hold',
                    $tx->type === 'debit' => 'debit',
                    $tx->type === 'refund' => 'refund',
                    default => 'credit',
                };

                return [
                    'uid' => 'WTX-' . $tx->id,
                    'id' => $tx->id,
                    'record_kind' => 'wallet_transaction',
                    'category' => $category,
                    'type' => $tx->type,
                    'actor_name' => $isCourier && !empty($meta['courier_name'])
                        ? $holderName . ' (Livreur : ' . $meta['courier_name'] . ')'
                        : $holderName,
                    'actor_type' => $isCourier ? 'Courier' : $holderType,
                    'amount' => (float) $tx->amount,
                    'balance_before' => (float) $tx->balance_before,
                    'balance_after' => (float) $tx->balance_after,
                    'partner_share' => null,
                    'edoctor_fee' => null,
                    'courier_share' => $isCourier ? (float) $tx->amount : null,
                    'status' => 'confirme',
                    'reference' => $tx->source_type
                        ? strtoupper($tx->source_type) . ' #' . ($tx->source_id ?? '')
                        : ('WTX-' . $tx->id),
                    'description' => $tx->description ?? 'Mouvement de portefeuille',
                    'created_at' => $tx->created_at?->toIso8601String() ?? '',
                ];
            });

        // 2. Paiements des patients (consultations & commandes en pharmacie)
        $payments = Payment::with(['consultation.patient', 'consultation.doctor', 'order.patient', 'order.pharmacy'])
            ->latest()
            ->limit(150)
            ->get()
            ->map(function (Payment $p) {
                $patientName = $p->consultation?->patient?->name
                    ?? $p->order?->patient?->name
                    ?? 'Patient eDoctor';

                if ($p->consultation_id) {
                    $docName = $p->consultation?->doctor?->name ?? 'Praticien';
                    $refCode = $p->consultation?->reference_code ?? ('#' . $p->consultation_id);
                    $desc = "Paiement téléconsultation {$refCode} ({$docName})";
                } elseif ($p->order_id) {
                    $pharmName = $p->order?->pharmacy?->name ?? 'Pharmacie';
                    $desc = "Paiement commande pharmacie #{$p->order_id} ({$pharmName})";
                } else {
                    $desc = "Paiement patient #{$p->id}";
                }

                return [
                    'uid' => 'PAY-' . $p->id,
                    'id' => $p->id,
                    'record_kind' => 'payment',
                    'category' => 'patient_payment',
                    'type' => $p->method ?? 'mobile_money',
                    'actor_name' => $patientName,
                    'actor_type' => 'Patient',
                    'amount' => (float) $p->amount,
                    'balance_before' => null,
                    'balance_after' => null,
                    'partner_share' => (float) ($p->partner_share ?? 0),
                    'edoctor_fee' => (float) ($p->edoctor_fee ?? 0),
                    'courier_share' => (float) ($p->courier_share ?? 0),
                    'status' => $p->status ?? 'en_attente',
                    'reference' => $p->transaction_ref ?? ('PAY-' . $p->id),
                    'description' => $desc,
                    'created_at' => $p->created_at?->toIso8601String() ?? '',
                ];
            });

        $merged = $walletTxs
            ->concat($payments)
            ->sortByDesc('created_at')
            ->values();

        return response()->json([
            'success' => true,
            'total' => $merged->count(),
            'transactions' => $merged,
        ]);
    }
}
