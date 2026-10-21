<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PayoutRequest;
use App\Models\Wallet;
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

        return response()->json([
            'success' => true,
            'summary' => [
                'total_available_balance' => (float) $totalAvailable,
                'total_escrow_pending_balance' => (float) $totalPending,
                'total_ecosystem_balance' => (float) ($totalAvailable + $totalPending),
                'wallets_count' => $wallets->count(),
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
}
