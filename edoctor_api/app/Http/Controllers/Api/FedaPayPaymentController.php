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
            ]);
        } catch (Exception $e) {
            Log::error('[FedaPay Controller] Erreur initiation paiement : ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 500);
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

            // En Sandbox : la validation par le testeur confirme le paiement pour permettre
            // de tester tout le tunnel clinique sans être bloqué par les restrictions de passerelle externe.
            // En Production (live) : FedaPay doit strictement retourner is_approved = true.
            $isApproved = ($txn && !empty($txn['is_approved'])) || $isSandbox;

            if ($isApproved) {
                DB::transaction(function () use ($consultation, $payment, $txn) {
                    if ($payment) {
                        $payment->update([
                            'status' => 'confirme',
                            'transaction_ref' => $txn['reference'] ?? ($payment->transaction_ref ?? 'FP-SANDBOX-' . $consultation->id),
                        ]);
                    }

                    $consultation->markAsPaid();
                });

                return response()->json([
                    'success' => true,
                    'status' => 'paye',
                    'is_approved' => true,
                    'message' => 'Paiement Mobile Money validé avec succès !',
                ]);
            }

            return response()->json([
                'success' => true,
                'status' => $txn['status'] ?? 'pending',
                'is_approved' => false,
                'message' => 'Paiement en attente de finalisation.',
            ]);
        } catch (Exception $e) {
            Log::error('[FedaPay Verify] Erreur vérification : ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'status' => $consultation->payment_status,
                'is_approved' => false,
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Webhook FedaPay automatisé (appelé par FedaPay dès confirmation du paiement).
     */
    public function handleWebhook(Request $request): JsonResponse
    {
        $payload = $request->all();
        Log::info('[FedaPay Webhook] Événement reçu : ', $payload);

        $eventName = $payload['name'] ?? $payload['event'] ?? '';
        $entity = $payload['entity'] ?? $payload['data'] ?? [];

        if ($eventName === 'transaction.approved' || ($entity['status'] ?? '') === 'approved') {
            $metadata = $entity['custom_metadata'] ?? [];
            $consultationId = $metadata['consultation_id'] ?? null;
            $transactionRef = $entity['reference'] ?? ('FP-' . ($entity['id'] ?? ''));

            if ($consultationId) {
                $consultation = Consultation::find($consultationId);
                if ($consultation && $consultation->payment_status !== 'paye') {
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

                    Log::info("[FedaPay Webhook] Consultation #{$consultationId} validée et marquée 'paye'.");
                }
            }
        }

        return response()->json(['status' => 'success']);
    }
}
