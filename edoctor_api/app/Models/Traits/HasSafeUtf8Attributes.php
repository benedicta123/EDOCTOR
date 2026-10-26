<?php

namespace App\Models\Traits;

trait HasSafeUtf8Attributes
{
    /**
     * Nettoie et garantit un encodage UTF-8 valide pour tous les attributs chaînes.
     * Empêche formellement l'erreur "Malformed UTF-8 characters" lors de la sérialisation JSON.
     */
    public function attributesToArray()
    {
        $attributes = parent::attributesToArray();

        return array_map(function ($value) {
            if (is_string($value)) {
                return mb_convert_encoding($value, 'UTF-8', 'UTF-8');
            }
            return $value;
        }, $attributes);
    }
}
