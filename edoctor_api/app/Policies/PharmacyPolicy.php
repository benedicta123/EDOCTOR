<?php

namespace App\Policies;

use App\Models\Pharmacy;
use App\Models\User;

class PharmacyPolicy
{
    public function view(?User $user, Pharmacy $pharmacy): bool
    {
        return true;
    }

    public function update(User $user, Pharmacy $pharmacy): bool
    {
        return ($user->isPharmacist() && $pharmacy->owner_id === $user->id) || $user->isAdmin();
    }

    public function manageStocks(User $user, Pharmacy $pharmacy): bool
    {
        return ($user->isPharmacist() && $pharmacy->owner_id === $user->id) || $user->isAdmin();
    }
}
