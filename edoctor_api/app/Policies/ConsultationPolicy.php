<?php

namespace App\Policies;

use App\Models\Consultation;
use App\Models\User;

class ConsultationPolicy
{
    public function view(User $user, Consultation $consultation): bool
    {
        return $consultation->isParticipant($user);
    }

    public function start(User $user, Consultation $consultation): bool
    {
        return $user->id === $consultation->doctor_id && $consultation->status === 'en_attente';
    }

    public function decline(User $user, Consultation $consultation): bool
    {
        return $user->id === $consultation->doctor_id && $consultation->status === 'en_attente';
    }

    public function end(User $user, Consultation $consultation): bool
    {
        return $user->id === $consultation->doctor_id;
    }

    public function cancel(User $user, Consultation $consultation): bool
    {
        return $consultation->isParticipant($user);
    }

    // Utilisée aussi par MessageController — envoyer un message suppose d'être participant.
    public function sendMessage(User $user, Consultation $consultation): bool
    {
        return $consultation->isParticipant($user);
    }
}
