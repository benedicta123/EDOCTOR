<?php

namespace App\Policies;

use App\Models\NurseVisit;
use App\Models\User;

class NurseVisitPolicy
{
    // Liste et assignation : réservées à l'administrateur DU MÊME hôpital.
    public function manageAsHospitalAdmin(User $user, NurseVisit $nurseVisit): bool
    {
        return $user->isAdmin() && $user->hospital_id === $nurseVisit->hospital_id;
    }

    // Accepter / décliner / terminer : réservées à l'infirmière assignée.
    public function respond(User $user, NurseVisit $nurseVisit): bool
    {
        return $user->id === $nurseVisit->nurse_id;
    }
}
