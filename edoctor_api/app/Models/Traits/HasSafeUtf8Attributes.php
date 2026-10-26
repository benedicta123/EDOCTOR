<?php

namespace App\Models\Traits;

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
     * Nettoyage UTF-8 récursif en profondeur pour tout tableau, objet ou valeur scalaire.
     */
    protected function sanitizeUtf8Recursive($data)
    {
        if (is_string($data)) {
            return mb_convert_encoding($data, 'UTF-8', 'UTF-8');
        }

        if (is_array($data)) {
            $cleaned = [];
            foreach ($data as $key => $value) {
                $cleanKey = is_string($key) ? mb_convert_encoding($key, 'UTF-8', 'UTF-8') : $key;
                $cleaned[$cleanKey] = $this->sanitizeUtf8Recursive($value);
            }
            return $cleaned;
        }

        return $data;
    }
}
