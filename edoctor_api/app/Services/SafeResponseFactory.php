<?php

namespace App\Services;

use Illuminate\Http\JsonResponse;
use Illuminate\Routing\ResponseFactory;

class SafeResponseFactory extends ResponseFactory
{
    /**
     * Crée une réponse JSON sécurisée contre les erreurs de caractères malformés.
     * En injectant JSON_INVALID_UTF8_SUBSTITUTE et JSON_UNESCAPED_UNICODE,
     * PHP remplace automatiquement les octets invalides sans jamais lever d'exception.
     */
    public function json($data = [], $status = 200, array $headers = [], $options = 0)
    {
        $options |= JSON_INVALID_UTF8_SUBSTITUTE | JSON_UNESCAPED_UNICODE;

        return new JsonResponse($data, $status, $headers, $options);
    }
}
