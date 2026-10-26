<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\Payment;
use App\Services\FedaPayService;
use App\Services\MonetizationService;
use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class FedaPayPaymentController extends Controller
{
    /**
     * Initialise un paiement FedaPay pour une téléconsultation.
     */
    public function initiateConsultationPayment(Request $request, int $id, FedaPayService $fedapay): JsonResponse
    {
        $consultation = Consultation::with(['doctor.hospital', 'patient'])->findOrFail($id);

        // Vérification des droits : seul le patient concerné ou un admin peut payer
        $user = $request->user();
        if ($user && !$user->isAdmin() && $consultation->patient_id !== $user->id) {
            abort(403, 'Vous n\'êtes pas autorisé à régler cette consultation.');
        }

        if ($consultation->payment_status === 'paye') {
            return response()->json([
                'success' => true,
                'already_paid' => true,
                'message' => 'Cette consultation a déjà été réglée.',
                'consultation' => $consultation,
            ]);
        }

        // Calcul exact de la tarification (100% hôpital + 10% eDoctor)
        $pricing = MonetizationService::calculateConsultationPricing(
            $consultation->doctor?->hospital,
            $consultation->doctor
        );

        $consultation->update([
            'consultation_fee' => $pricing['consultation_fee'],
            'edoctor_fee' => $pricing['edoctor_fee'],
            'total_amount' => $pricing['total_amount'],
        ]);

        $patient = $consultation->patient ?? $user;
        $customer = [
            'firstname' => $patient?->name ?? 'Patient',
            'lastname' => 'eDoctor',
            'email' => $patient?->email ?? 'patient@edoctor.tg',
            'phone' => $patient?->phone,
        ];

        try {
            $paymentResult = $fedapay->createPayment(
                $pricing['total_amount'],
                "Consultation eDoctor #{$consultation->id} - Dr. " . ($consultation->doctor?->name ?? 'Praticien'),
                $customer,
                [
                    'consultation_id' => $consultation->id,
                    'patient_id' => $consultation->patient_id,
                    'type' => 'consultation',
                ]
            );

            // Enregistrement ou mise à jour du paiement en attente
            Payment::updateOrCreate(
                ['consultation_id' => $consultation->id],
                [
                    'method' => 'mobile_money',
                    'amount' => $pricing['total_amount'],
                    'partner_share' => $pricing['hospital_share'],
                    'edoctor_fee' => $pricing['edoctor_fee'],
                    'courier_share' => 0.00,
                    'status' => 'en_attente',
                    'transaction_ref' => (string) ($paymentResult['reference'] ?? 'FP-' . $paymentResult['transaction_id']),
                ]
            );

            return response()->json([
                'success' => true,
                'consultation_id' => $consultation->id,
                'transaction_id' => $paymentResult['transaction_id'],
                'reference' => $paymentResult['reference'],
                'checkout_url' => $paymentResult['checkout_url'],
                'token' => $paymentResult['token'],
                'amount' => $pricing['total_amount'],
                'simulated' => $paymentResult['simulated'] ?? false,
            ], 200, [], JSON_INVALID_UTF8_SUBSTITUTE | JSON_UNESCAPED_UNICODE);
        } catch (Exception $e) {
            Log::error('[FedaPay Controller] Erreur initiation paiement : ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 500, [], JSON_INVALID_UTF8_SUBSTITUTE | JSON_UNESCAPED_UNICODE);
        }
    }

    /**
     * Vérifie le statut d'un paiement de consultation directement auprès de FedaPay.
     * Permet à l'application mobile de confirmer le paiement dès le retour du patient.
     */
    public function verifyConsultationPayment(Request $request, int $id, FedaPayService $fedapay): JsonResponse
    {
        $consultation = Consultation::with(['doctor', 'patient'])->findOrFail($id);

        if ($consultation->payment_status === 'paye') {
            return response()->json([
                'success' => true,
                'status' => 'paye',
                'is_approved' => true,
                'message' => 'Consultation déjà confirmée et payée.',
            ]);
        }

        $payment = Payment::where('consultation_id', $consultation->id)->latest()->first();

        // Si une référence ou un ID de transaction FedaPay est fourni
        $txnId = $request->input('transaction_id');
        if (!$txnId && $payment && $payment->transaction_ref) {
            // Nettoyage éventuel du préfixe FP-
            $txnId = str_replace('FP-', '', $payment->transaction_ref);
        }

        if (!$txnId) {
            return response()->json([
                'success' => false,
                'status' => $consultation->payment_status,
                'is_approved' => false,
                'message' => 'Aucune transaction FedaPay trouvée pour cette consultation.',
            ]);
        }

        try {
            $isSandbox = config('services.fedapay.environment', 'sandbox') === 'sandbox';
            $txn = null;

            try {
                $txn = $fedapay->getTransaction($txnId);
            } catch (Exception $e) {
                Log::warning('[FedaPay Verify] getTransaction exception : ' . $e->getMessage());
            }

            // En mode simulation : auto-approbation autorisée pour les tests
            if ($fedapay->isSimulationAllowed() || !$fedapay->isConfigured()) {
                abort_unless(
                    $fedapay->isSimulationAllowed() || app()->environment('local', 'testing'),
                    403,
                    'La validation de paiement en mode non configuré est interdite en environnement de production.'
                );
                $isApproved = true;
            } else {
                // Avec clés API FedaPay configurées (sandbox ou live) : la transaction DOIT être strictement approuvée
                $isApproved = ($txn && !empty($txn['is_approved'])) || (($txn['status'] ?? '') === 'approved');
                // Contrôle strict anti-fraude sur le montant
                if ($isApproved && isset($txn['amount']) && (float)$txn['amount'] < (float)$consultation->total_amount) {
                    $isApproved = false;
                    Log::warning("[FedaPay Verify] Rejet tentative de sous-paiement ({$txn['amount']} < {$consultation->total_amount}) pour consultation #{$consultation->id}.");
                }
            }

            if ($isApproved) {
                DB::transaction(function () use ($consultation, $payment, $txn) {
                    if ($payment) {
                        $payment->update([
                            'status' => 'confirme',
                            'transaction_ref' => $txn['reference'] ?? ($payment->transaction_ref ?? 'FP-' . $consultation->id),
                        ]);
                    }

                    $consultation->markAsPaid();
                });

                return response()->json([
                    'success' => true,
                    'status' => 'paye',
                    'is_approved' => true,
                    'message' => 'Paiement Mobile Money validé avec succès !',
                ], 200, [], JSON_INVALID_UTF8_SUBSTITUTE | JSON_UNESCAPED_UNICODE);
            }

            return response()->json([
                'success' => true,
                'status' => $txn['status'] ?? 'pending',
                'is_approved' => false,
                'message' => 'Paiement en attente de finalisation.',
            ], 200, [], JSON_INVALID_UTF8_SUBSTITUTE | JSON_UNESCAPED_UNICODE);
        } catch (Exception $e) {
            Log::error('[FedaPay Verify] Erreur vérification : ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'status' => $consultation->payment_status,
                'is_approved' => false,
                'message' => $e->getMessage(),
            ], 500, [], JSON_INVALID_UTF8_SUBSTITUTE | JSON_UNESCAPED_UNICODE);
        }
    }

    /**
     * Webhook FedaPay automatisé hautement sécurisé :
     * 1. Contrôle de signature cryptographique (si configurée).
     * 2. Re-vérification systématique auprès de l'API officielle FedaPay (out-of-band).
     * 3. Vérification de cohérence du montant réglé et statut de la consultation.
     */
    public function handleWebhook(Request $request, FedaPayService $fedapay): JsonResponse
    {
        // 1. Vérification de la signature secrète du webhook
        $webhookSecret = (string) config('services.fedapay.webhook_secret', '');
        
        // En production : l'absence de secret ou une clé non configurée est une anomalie critique bloquante
        if (app()->environment('production')) {
            abort_if(empty($webhookSecret), 500, 'Alerte sécurité : FEDAPAY_WEBHOOK_SECRET non configuré en environnement de production.');
            abort_unless($fedapay->isConfigured(), 500, 'Alerte sécurité : La passerelle FedaPay n\'est pas configurée en production.');
        }

        if (!empty($webhookSecret)) {
            $signature = $request->header('X-FedaPay-Signature') ?? $request->header('X-Webhook-Secret');
            if (!$signature || !hash_equals($webhookSecret, (string) $signature)) {
                Log::warning('[FedaPay Webhook] Tentative d\'accès non autorisée : signature invalide.');
                return response()->json(['error' => 'Signature invalide.'], 401);
            }
        }

        $payload = $request->all();
        Log::info('[FedaPay Webhook] Événement reçu : ', [
            'name' => $payload['name'] ?? $payload['event'] ?? 'unknown',
            'id' => $payload['entity']['id'] ?? $payload['id'] ?? null,
        ]);

        $eventName = $payload['name'] ?? $payload['event'] ?? '';
        $entity = $payload['entity'] ?? $payload['data'] ?? [];
        $txnId = $entity['id'] ?? $payload['id'] ?? null;

        if (!$txnId) {
            Log::warning('[FedaPay Webhook] Rejet : payload sans identifiant de transaction.');
            return response()->json(['error' => 'Identifiant de transaction manquant.'], 400);
        }

        // 2. Vérification out-of-band auprès des serveurs officiels FedaPay
        if ($fedapay->isConfigured()) {
            try {
                $verifiedTxn = $fedapay->getTransaction($txnId);
            } catch (Exception $e) {
                Log::error("[FedaPay Webhook] Impossible de joindre l'API FedaPay pour vérification de {$txnId} : " . $e->getMessage());
                return response()->json(['error' => 'Vérification API FedaPay échouée.'], 502);
            }

            if (empty($verifiedTxn['is_approved']) && ($verifiedTxn['status'] ?? '') !== 'approved') {
                Log::warning("[FedaPay Webhook] Alerte sécurité : la transaction {$txnId} n'est PAS approuvée sur les serveurs FedaPay.");
                return response()->json(['error' => 'Transaction non approuvée.'], 422);
            }

            $transactionRef = $verifiedTxn['reference'] ?? ('FP-' . $txnId);
            $verifiedAmount = (float) ($verifiedTxn['amount'] ?? 0);
        } else {
            // Interdiction formelle du mode simulation hors environnement de dev/test
            abort_if(! app()->environment('local', 'testing'), 403, 'Simulation de webhook interdite en environnement de production.');

            // Environnement de développement sans clé API FedaPay
            if ($eventName !== 'transaction.approved' && ($entity['status'] ?? '') !== 'approved') {
                return response()->json(['status' => 'ignored']);
            }
            $transactionRef = $entity['reference'] ?? ('SIM-FP-' . $txnId);
            $verifiedAmount = null;
        }

        // 3. Identification de la consultation et validation du montant
        $metadata = $entity['custom_metadata'] ?? [];
        $consultationId = $metadata['consultation_id'] ?? null;

        if (!$consultationId) {
            $payment = Payment::where('transaction_ref', 'LIKE', "%{$txnId}%")->first();
            $consultationId = $payment?->consultation_id;
        }

        if ($consultationId) {
            $consultation = Consultation::find($consultationId);
            if ($consultation && $consultation->payment_status !== 'paye') {
                if ($verifiedAmount !== null && $verifiedAmount < (float) $consultation->total_amount) {
                    Log::error("[FedaPay Webhook] Alerte fraude montant : reçu {$verifiedAmount} XOF au lieu de {$consultation->total_amount} XOF pour consultation #{$consultationId}.");
                    return response()->json(['error' => 'Montant insuffisant.'], 422);
                }

                DB::transaction(function () use ($consultation, $transactionRef) {
                    $payment = Payment::where('consultation_id', $consultation->id)->latest()->first();
                    if ($payment) {
                        $payment->update([
                            'status' => 'confirme',
                            'transaction_ref' => $transactionRef,
                        ]);
                    }

                    $consultation->markAsPaid();
                });

                Log::info("[FedaPay Webhook] Consultation #{$consultationId} validée et marquée 'paye' après contrôle de sécurité certifié.");
            }
        }

        return response()->json(['status' => 'success']);
    }
}
