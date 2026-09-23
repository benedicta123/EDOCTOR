<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\User;

class NotificationService
{
    /**
     * Point d'entrée unique pour créer une notification — à appeler depuis
     * n'importe quel contrôleur (commande prête, prescription validée, etc.)
     * plutôt que de dupliquer Notification::create(...) partout.
     */
    public static function send(User $user, string $type, string $content): Notification
    {
        return Notification::create([
            'user_id' => $user->id,
            'type' => $type,
            'content' => $content,
            'read' => false,
        ]);
    }
}
