<?php

namespace App\Services;

use Exception;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FedaPayService
{
    protected string $secretKey;
    protected string $environment;
    protected string $baseUrl;

    public function __construct(?string $secretKey = null, ?string $environment = null)
    {
        $this->secretKey = $secretKey ?? (string) config('services.fedapay.secret_key', '');
        $this->environment = $environment ?? (string) config('services.fedapay.environment', 'sandbox');

        $this->baseUrl = ($this->environment === 'live')
            ? 'https://api.fedapay.com/v1'
            : 'https://sandbox-api.fedapay.com/v1';
    }

    /**
     * Vérifie si les clés FedaPay sont configurées.
     */
    public function isConfigured(): bool
    {
        return !empty($this->secretKey) && !str_starts_with($this->secretKey, 'votre_cle_ici');
    }

    /**
     * Crée une transaction sur FedaPay et génère son URL de checkout.
     *
     * @param float $amount Montant en FCFA (XOF)
     * @param string $description Libellé de la transaction
     * @param array $customer Infos patient [firstname, lastname, email, phone]
     * @param array $metadata Métadonnées eDoctor (consultation_id, etc.)
     * @param string|null $callbackUrl URL de redirection après paiement
     * @return array [transaction_id, reference, token, checkout_url, amount]
     * @throws Exception
     */
    public function createPayment(
        float $amount,
        string $description,
        array $customer,
        array $metadata = [],
        ?string $callbackUrl = null
    ): array {
        // Mode Simulation si la clé API n'a pas encore été renseignée
        if (!$this->isConfigured()) {
            Log::warning('[FedaPayService] Clé API FedaPay non configurée. Génération d\'un paiement simulé.');
            $mockTxnId = rand(100000, 999999);
            return [
                'simulated' => true,
                'transaction_id' => $mockTxnId,
                'reference' => 'SIM-FP-' . strtoupper(bin2hex(random_bytes(4))),
                'token' => 'sim_token_' . bin2hex(random_bytes(8)),
                'checkout_url' => 'https://sandbox-checkout.fedapay.com/simulated?ref=SIM-' . $mockTxnId,
                'amount' => round($amount, 2),
            ];
        }

        $formattedCustomer = [
            'firstname' => $customer['firstname'] ?? 'Patient',
            'lastname' => $customer['lastname'] ?? 'eDoctor',
            'email' => $customer['email'] ?? 'patient@edoctor.tg',
        ];

        if (!empty($customer['phone'])) {
            $phoneClean = preg_replace('/[^0-9]/', '', $customer['phone']);
            // En production, on cible le Togo par défaut ('tg')
            // En sandbox, on ne verrouille pas le pays pour permettre le choix libre du pays et des numéros de test
            if ($this->environment === 'live') {
                $formattedCustomer['phone_number'] = [
                    'number' => $phoneClean,
                    'country' => 'tg',
                ];
            }
        }

        $payload = [
            'description' => $description,
            'amount' => (int) round($amount), // FedaPay utilise des montants entiers pour le FCFA (XOF)
            'currency' => ['iso' => 'XOF'],
            'customer' => $formattedCustomer,
            'custom_metadata' => $metadata,
        ];

        if ($callbackUrl) {
            $payload['callback_url'] = $callbackUrl;
        }

        // 1. Créer la transaction sur l'API FedaPay
        $response = Http::withHeaders([
            'Authorization' => 'Bearer ' . $this->secretKey,
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
        ])->timeout(15)->post("{$this->baseUrl}/transactions", $payload);

        if (!$response->successful()) {
            Log::error('[FedaPayService] Échec création transaction : ', [
                'status' => $response->status(),
                'body' => $response->json() ?? $response->body(),
            ]);
            $errorMsg = $response->json('message') ?? 'Erreur lors de la communication avec FedaPay.';
            throw new Exception("FedaPay : {$errorMsg}");
        }

        $txnData = $response->json('v1/transaction') ?? $response->json('transaction') ?? $response->json();
        $transactionId = $txnData['id'] ?? null;
        $reference = $txnData['reference'] ?? null;

        if (!$transactionId) {
            throw new Exception("FedaPay n'a pas retourné d'identifiant de transaction.");
        }

        // 2. Générer le Token de paiement (Checkout URL)
        $tokenResponse = Http::withHeaders([
            'Authorization' => 'Bearer ' . $this->secretKey,
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
        ])->timeout(15)->post("{$this->baseUrl}/transactions/{$transactionId}/token");

        if (!$tokenResponse->successful()) {
            Log::error('[FedaPayService] Échec génération token : ', [
                'status' => $tokenResponse->status(),
                'body' => $tokenResponse->json() ?? $tokenResponse->body(),
            ]);
            throw new Exception("Impossible de générer le lien de paiement FedaPay.");
        }

        $tokenData = $tokenResponse->json();
        $token = null;
        $checkoutUrl = null;

        if (is_array($tokenData)) {
            $token = $tokenData['token'] ?? ($tokenData['v1/token']['token'] ?? null);
            $checkoutUrl = $tokenData['url'] ?? ($tokenData['v1/token']['url'] ?? null);
        }

        // Fallbacks directs depuis la transaction
        $token = $token ?? ($txnData['payment_token'] ?? null);
        $checkoutUrl = $checkoutUrl ?? ($txnData['payment_url'] ?? ($token ? "https://checkout.fedapay.com/{$token}" : null));

        return [
            'simulated' => false,
            'transaction_id' => $transactionId,
            'reference' => $reference,
            'token' => $token,
            'checkout_url' => $checkoutUrl,
            'amount' => round($amount, 2),
        ];
    }

    /**
     * Interroge l'état réel d'une transaction directement auprès de FedaPay.
     *
     * @param int|string $transactionId
     * @return array [id, status, amount, reference, is_approved]
     * @throws Exception
     */
    public function getTransaction(int|string $transactionId): array
    {
        // En mode simulation
        if (!$this->isConfigured()) {
            return [
                'id' => $transactionId,
                'status' => 'approved',
                'is_approved' => true,
                'simulated' => true,
            ];
        }

        $response = Http::withHeaders([
            'Authorization' => 'Bearer ' . $this->secretKey,
            'Accept' => 'application/json',
        ])->timeout(12)->get("{$this->baseUrl}/transactions/{$transactionId}");

        if (!$response->successful()) {
            throw new Exception("Transaction FedaPay introuvable ou erreur API.");
        }

        $txn = $response->json('v1/transaction') ?? $response->json('transaction') ?? $response->json();
        $status = strtolower($txn['status'] ?? 'pending');

        return [
            'id' => $txn['id'] ?? $transactionId,
            'status' => $status,
            'amount' => (float) ($txn['amount'] ?? 0),
            'reference' => $txn['reference'] ?? null,
            'is_approved' => ($status === 'approved'),
            'raw' => $txn,
        ];
    }
}
