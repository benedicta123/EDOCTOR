<?php

namespace App\Services;

use App\Models\Consultation;
use App\Models\User;
use RuntimeException;

/**
 * Génération serveur des JWT Jitsi-as-a-Service (8x8.vc).
 *
 * Le secret (clé privée RSA) ne quitte JAMAIS Laravel : signature RS256
 * via OpenSSL, aucun log du token complet ni de la clé.
 */
class JaasService
{
    /**
     * Nom de salle unique par consultation : haute entropie cryptographique (SHA-256 HMAC 128-bit),
     * strictement déterministe pour le médecin et le patient autorisés, mais totalement
     * imprévisible et infalsifiable de l'extérieur. Aucune donnée médicale en clair.
     */
    public function roomName(Consultation $consultation): string
    {
        $context = implode(':', [
            'consultation',
            $consultation->id,
            $consultation->patient_id,
            $consultation->doctor_id,
            $consultation->created_at?->timestamp ?? '0',
        ]);

        $mac = hash_hmac(
            'sha256',
            $context,
            (string) config('app.key')
        );

        return 'edoctor-'.substr($mac, 0, 32);
    }

    /**
     * @return array{server_url:string,domain:string,app_id:string,room_name:string,jwt:string,expires_at:string}
     */
    public function joinPayload(Consultation $consultation, User $user): array
    {
        $appId = (string) config('jaas.app_id');
        $keyId = (string) config('jaas.key_id');
        $keyPath = (string) config('jaas.private_key_path');
        $domain = (string) config('jaas.domain', '8x8.vc');
        $ttl = (int) config('jaas.token_ttl', 7200);

        abort_if($appId === '' || $keyId === '', 503,
            'Visioconférence non configurée (JAAS_APP_ID / JAAS_KEY_ID manquants).');
        // NOTE : les ID de clé JaaS sont courts (ex. {APP_ID}/3a0565) — aucun
        // contrôle de format ici. Si 8x8 rejette le JWT (« Authentication
        // failed »), c'est que JAAS_KEY_ID et/ou la clé privée ne correspondent
        // pas à la même clé API de la console.
        abort_if(! is_file($keyPath) || ! is_readable($keyPath), 503,
            'Visioconférence non configurée (clé privée JaaS introuvable).');

        // À appeler AVANT toute opération OpenSSL du processus : la
        // bibliothèque fige sa configuration au premier usage.
        self::ensureOpensslEnvironment();

        $privateKey = @file_get_contents($keyPath);
        abort_if($privateKey === false, 503,
            'Visioconférence non configurée (clé privée JaaS illisible).');

        $key = @openssl_pkey_get_private($privateKey);
        abort_if($key === false, 503,
            'Visioconférence non configurée (clé privée JaaS invalide).');

        $now = time();
        $room = $this->roomName($consultation);
        $isDoctor = $user->id === $consultation->doctor_id;

        $header = ['alg' => 'RS256', 'typ' => 'JWT', 'kid' => $keyId];
        $payload = [
            'aud' => 'jitsi',
            'iss' => 'chat',
            'sub' => $appId,
            'room' => $room,
            'nbf' => $now - 10,
            'exp' => $now + $ttl,
            'context' => [
                'user' => [
                    'id' => (string) $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'moderator' => $isDoctor,
                ],
                'features' => [
                    'recording' => false,
                    'livestreaming' => false,
                ],
            ],
        ];

        $segments = [
            $this->base64Url(json_encode($header)),
            $this->base64Url(json_encode($payload)),
        ];
        $signature = '';
        $signed = @openssl_sign(
            implode('.', $segments), $signature, $key, OPENSSL_ALGO_SHA256
        );
        if (is_resource($key)) {
            @openssl_pkey_free($key);
        }
        abort_if(! $signed, 503, 'Visioconférence indisponible (signature JWT impossible).');

        $segments[] = $this->base64Url($signature);

        return [
            'server_url' => 'https://'.$domain.'/'.$appId,
            'domain' => $domain,
            'app_id' => $appId,
            'room_name' => $room,
            'jwt' => implode('.', $segments),
            'expires_at' => gmdate('Y-m-d\TH:i:s\Z', $now + $ttl),
        ];
    }

    private function base64Url(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    /**
     * Garantit OPENSSL_CONF avant le premier usage OpenSSL du processus.
     * Indispensable sur certains PHP Windows sans openssl.cnf par défaut ;
     * sans effet sur Linux où OpenSSL trouve déjà le sien.
     */
    public static function ensureOpensslEnvironment(): void
    {
        if (is_string(getenv('OPENSSL_CONF')) && getenv('OPENSSL_CONF') !== '') {
            return;
        }
        $cnf = self::resolveOpensslCnf();
        if ($cnf !== null) {
            putenv('OPENSSL_CONF='.$cnf);
            $_ENV['OPENSSL_CONF'] = $cnf;
            $_SERVER['OPENSSL_CONF'] = $cnf;
        }
    }

    /**
     * Localise un openssl.cnf exploitable (Windows uniquement en pratique ;
     * sur Linux, OpenSSL trouve le sien seul et cette méthode ne sert pas).
     */
    private static function resolveOpensslCnf(): ?string
    {
        $candidates = [
            (string) config('jaas.openssl_cnf', ''),
            (string) (getenv('OPENSSL_CONF') ?: ''),
            dirname(PHP_BINARY).DIRECTORY_SEPARATOR
                .'extras'.DIRECTORY_SEPARATOR
                .'ssl'.DIRECTORY_SEPARATOR.'openssl.cnf',
        ];
        foreach ($candidates as $path) {
            if ($path !== '' && is_file($path) && is_readable($path)) {
                return $path;
            }
        }

        return null;
    }
}
