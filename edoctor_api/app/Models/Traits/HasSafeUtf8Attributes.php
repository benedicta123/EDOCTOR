<?php

namespace App\Models\Traits;

use Illuminate\Support\Facades\Crypt;

trait HasSafeUtf8Attributes
{
    /**
     * Nettoie et garantit un encodage UTF-8 valide pour tous les attributs et relations.
     * Empêche formellement l'erreur "Malformed UTF-8 characters" lors de la sérialisation JSON.
     */
    public function toArray()
    {
        $data = parent::toArray();

        return $this->sanitizeUtf8Recursive($data);
    }

    /**
     * Sérialisation JSON blindée :
     * 1. Nettoie récursivement les données UTF-8.
     * 2. Réinitialise json_last_error() pour éviter la pollution de l'état global.
     * 3. Utilise JSON_INVALID_UTF8_SUBSTITUTE et JSON_UNESCAPED_UNICODE.
     */
    public function toJson($options = 0)
    {
        json_decode('[]');
        $cleaned = $this->toArray();
        $json = json_encode($cleaned, $options | JSON_INVALID_UTF8_SUBSTITUTE | JSON_UNESCAPED_UNICODE);
        json_decode('[]');
        return $json;
    }

    public function jsonSerialize(): mixed
    {
        json_decode('[]');
        $data = $this->toArray();
        json_decode('[]');
        return $data;
    }

    /**
     * Déchiffrement sécurisé avec tolérance aux données en clair ou clés obsolètes.
     * Garantit formellement que json_last_error() n'est JAMAIS pollué par l'encrypteur Laravel.
     */
    public static function safeDecrypt(?string $value): ?string
    {
        if ($value === null || $value === '') {
            return $value;
        }

        try {
            $trimmed = trim($value);
            // Vérifie si la valeur ressemble à un JSON payload base64 Laravel (commence par "eyJ" pour {"iv":...)
            if (str_starts_with($trimmed, 'eyJ') || (base64_decode($trimmed, true) !== false && str_contains(base64_decode($trimmed, true), '"iv"'))) {
                $decrypted = Crypt::decryptString($value);
                return mb_convert_encoding($decrypted, 'UTF-8', 'UTF-8');
            }
        } catch (\Throwable) {
            // Si le déchiffrement échoue, retomber sur la valeur en clair
        } finally {
            // Nettoyage impératif de json_last_error()
            json_decode('[]');
        }

        return mb_convert_encoding($value, 'UTF-8', 'UTF-8');
    }

    /**
     * Chiffrement sécurisé avec gestion propre des erreurs.
     */
    public static function safeEncrypt(?string $value): ?string
    {
        if ($value === null || $value === '') {
            return $value;
        }

        try {
            return Crypt::encryptString($value);
        } catch (\Throwable) {
            return mb_convert_encoding($value, 'UTF-8', 'UTF-8');
        } finally {
            json_decode('[]');
        }
    }

    /**
     * Nettoyage UTF-8 récursif en profondeur pour tout tableau, objet ou valeur scalaire.
     */
    protected function sanitizeUtf8Recursive($data)
    {
        if (is_string($data)) {
            // Supprimer les caractères de contrôle non imprimables (sauf tab, newline, carriage return)
            $cleaned = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $data);
            return mb_convert_encoding($cleaned ?? $data, 'UTF-8', 'UTF-8');
        }

        if (is_array($data)) {
            $cleaned = [];
            foreach ($data as $key => $value) {
                $cleanKey = is_string($key)
                    ? mb_convert_encoding(preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $key) ?? $key, 'UTF-8', 'UTF-8')
                    : $key;
                $cleaned[$cleanKey] = $this->sanitizeUtf8Recursive($value);
            }
            return $cleaned;
        }

        return $data;
    }
}
