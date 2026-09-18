<?php

namespace App\Policies;

use App\Models\Consultation;
use App\Models\Prescription;
use App\Models\User;

class PrescriptionPolicy
{
    public function view(User $user, Prescription $prescription): bool
    {
        return $prescription->isParticipant($user);
    }

    // Gate::authorize('create', [Prescription::class, $consultation])
    public function create(User $user, Consultation $consultation): bool
    {
        return $user->id === $consultation->doctor_id;
    }

    public function cancel(User $user, Prescription $prescription): bool
    {
        return $user->id === $prescription->doctor_id;
    }

    public function requestNurseVisit(User $user, Prescription $prescription): bool
    {
        return $user->id === $prescription->patient_id
            && $prescription->home_care_recommended;
    }
}
