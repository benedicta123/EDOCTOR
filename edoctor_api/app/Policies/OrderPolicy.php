<?php

namespace App\Policies;

use App\Models\Order;
use App\Models\User;

class OrderPolicy
{
    public function view(User $user, Order $order): bool
    {
        return $this->isPatientOwner($user, $order) || $this->isPharmacyOwner($user, $order);
    }

    // Actions réservées au pharmacien : mark-ready, mark-collected.
    public function managePharmacySide(User $user, Order $order): bool
    {
        return $this->isPharmacyOwner($user, $order);
    }

    public function cancel(User $user, Order $order): bool
    {
        return $this->isPatientOwner($user, $order) || $this->isPharmacyOwner($user, $order);
    }

    private function isPatientOwner(User $user, Order $order): bool
    {
        return $user->id === $order->patient_id;
    }

    private function isPharmacyOwner(User $user, Order $order): bool
    {
        return $user->isPharmacist() && $order->pharmacy->owner_id === $user->id;
    }
}
