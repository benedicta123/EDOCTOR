<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Jitsi as a Service (JaaS) — 8x8.vc
    |--------------------------------------------------------------------------
    |
    | La visioconférence eDoctor repose sur JaaS. Le domaine, l'App ID et la
    | clé privée vivent UNIQUEMENT côté serveur : le JWT est signé ici,
    | jamais dans Flutter. Valeurs réelles dans le fichier `.env` :
    |
    |   JAAS_APP_ID=votre-app-id-jaas
    |   JAAS_KEY_ID=votre-key-id (colonne "ID" de la clé API JaaS)
    |   JAAS_PRIVATE_KEY_PATH=/chemin/absolu/ou/relatif/vers/edoctor-private.pem
    |
    | Placer le fichier .pem téléchargé depuis la console JaaS
    | (https://jaas.8x8.vc) dans storage/app/jaas/ (dossier ignoré par git)
    | et pointer JAAS_PRIVATE_KEY_PATH dessus.
    |
    */

    'app_id' => env('JAAS_APP_ID'),

    'key_id' => env('JAAS_KEY_ID'),

    'private_key_path' => env(
        'JAAS_PRIVATE_KEY_PATH',
        storage_path('app/jaas/edoctor-private.pem')
    ),

    // Domaine JaaS (compte déjà créé).
    'domain' => env('JAAS_DOMAIN', '8x8.vc'),

    // Durée de validité du JWT en secondes (courte durée imposée).
    'token_ttl' => (int) env('JAAS_TOKEN_TTL', 7200),

    // Chemin openssl.cnf (Windows surtout). Vide = détection automatique.
    'openssl_cnf' => env('JAAS_OPENSSL_CNF'),

];
