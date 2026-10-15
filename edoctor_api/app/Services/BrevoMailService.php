<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class BrevoMailService
{
    /**
     * Envoie un email transactionnel via l'API REST v3 de Brevo.
     *
     * @param string $toEmail Adresse email du destinataire
     * @param string|null $toName Nom du destinataire
     * @param string $subject Sujet du message
     * @param string $textContent Contenu au format texte brut
     * @param string|null $htmlContent Contenu au format HTML optionnel
     * @return bool True si expédié avec succès, False sinon
     */
    public static function send(
        string $toEmail,
        ?string $toName,
        string $subject,
        string $textContent,
        ?string $htmlContent = null
    ): bool {
        $apiKey = config('services.brevo.api_key') ?? env('BREVO_API_KEY') ?? env('MAIL_PASSWORD');
        $fromEmail = config('mail.from.address') ?? env('MAIL_FROM_ADDRESS', 'contacts@ewaregroup.org');
        $fromName = config('mail.from.name') ?? env('MAIL_FROM_NAME', 'eDoctor Sécurité');

        if (empty($apiKey)) {
            Log::warning("[Brevo API] Impossible d'envoyer l'email : clé API Brevo manquante.");
            return false;
        }

        $payload = [
            'sender' => [
                'name' => $fromName,
                'email' => $fromEmail,
            ],
            'to' => [
                [
                    'email' => $toEmail,
                    'name' => $toName ?: $toEmail,
                ],
            ],
            'subject' => $subject,
            'textContent' => $textContent,
        ];

        if ($htmlContent) {
            $payload['htmlContent'] = $htmlContent;
        } else {
            $payload['htmlContent'] = nl2br(htmlspecialchars($textContent, ENT_QUOTES, 'UTF-8'));
        }

        try {
            $response = Http::withHeaders([
                'accept' => 'application/json',
                'api-key' => $apiKey,
                'content-type' => 'application/json',
            ])->timeout(10)->post('https://api.brevo.com/v3/smtp/email', $payload);

            if ($response->successful()) {
                $messageId = $response->json('messageId') ?? 'OK';
                Log::info("[Brevo API] Email envoyé avec succès à {$toEmail} (ID: {$messageId})");
                return true;
            }

            Log::error("[Brevo API] Échec envoi à {$toEmail} (HTTP {$response->status()}) : " . $response->body());
            return false;
        } catch (\Throwable $e) {
            Log::error("[Brevo API] Exception lors de l'envoi à {$toEmail} : " . $e->getMessage());
            return false;
        }
    }
}
