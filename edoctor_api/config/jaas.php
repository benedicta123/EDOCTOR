<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Jitsi as a Service (JaaS) — 8x8.vc
    |--------------------------------------------------------------------------
    |
    | La visioconférence eDoctor repose sur JaaS. Le domaine, l'App ID et la
    | clé privée vivent UNIQUEMENT côté serveur : le JWT est signé ici,
    | jamais dans Flutter. Valeurs réelles dans le fichier `.env` ou Dokploy :
    |
    |   JAAS_APP_ID=vpaas-magic-cookie-xxxx
    |   JAAS_KEY_ID=vpaas-magic-cookie-xxxx/xxxxxx
    |   JAAS_PRIVATE_KEY=-----BEGIN PRIVATE KEY... (ou base64 pour Dokploy)
    |   JAAS_PRIVATE_KEY_PATH=/chemin/vers/edoctor_privatekey.pk
    |
    */

    'app_id' => env('JAAS_APP_ID'),

    'key_id' => env('JAAS_KEY_ID'),

    // Clé privée brute ou encodée en base64 pour injection facile dans Dokploy
    'private_key' => env('JAAS_PRIVATE_KEY'),

    'private_key_path' => env(
        'JAAS_PRIVATE_KEY_PATH',
        storage_path('app/jaas/edoctor_privatekey.pk')
    ),

    // Domaine JaaS (compte déjà créé).
    'domain' => env('JAAS_DOMAIN', '8x8.vc'),

    // Durée de validité du JWT en secondes (7200s = 2 heures max).
    'token_ttl' => (int) env('JAAS_TOKEN_TTL', 7200),

    // Chemin openssl.cnf (Windows surtout). Vide = détection automatique.
    'openssl_cnf' => env('JAAS_OPENSSL_CNF'),

];
