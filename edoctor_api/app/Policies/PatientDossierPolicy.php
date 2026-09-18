<?php

namespace App\Policies;

use App\Models\User;

class PatientDossierPolicy
{
    /**
     * Accès au dossier patient :
     * - le patient lui-même (dossier personnel dans l'app mobile),
     * - un admin,
     * - le médecin uniquement s'il a déjà eu avec lui une consultation
     *   réellement tenue — pas une simple demande en attente,
     *   ni une consultation déclinée ou annulée.
     */
    public function view(User $user, User $patient): bool
    {
        if (! $patient->isPatient()) {
            return false;
        }

        if ($user->isAdmin()) {
            return $user->hospital_id !== null
                && \App\Models\Consultation::where('patient_id', $patient->id)
                    ->whereIn('status', ['en_cours', 'terminee'])
                    ->whereHas('doctor', fn ($q) => $q->where('hospital_id', $user->hospital_id))
                    ->exists();
        }

        if ($user->isPatient()) {
            return $user->id === $patient->id;
        }

        if (! $user->isDoctor()) {
            return false;
        }

        return \App\Models\Consultation::where('doctor_id', $user->id)
            ->where('patient_id', $patient->id)
            ->whereIn('status', ['en_cours', 'terminee'])
            ->exists();
    }
}
