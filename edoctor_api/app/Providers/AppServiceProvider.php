<?php

namespace App\Providers;

use App\Models\Consultation;
use App\Models\Pharmacy;
use App\Models\User;
use App\Policies\PatientDossierPolicy;
use App\Policies\PharmacyPolicy;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;
use Laravel\Sanctum\Sanctum;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Gate::define('viewPatientDossier', [PatientDossierPolicy::class, 'view']);
        Gate::policy(Pharmacy::class, PharmacyPolicy::class);

        // Règle critique : Ne JAMAIS faire expirer un token d'accès en cours de consultation vidéo
        Sanctum::authenticateAccessTokensUsing(function ($accessToken, $isValid) {
            if (! $accessToken) {
                return false;
            }

            $user = $accessToken->tokenable;

            if ($user instanceof User) {
                // Vérifie si l'utilisateur participe à une consultation vidéo active
                $hasActiveConsultation = Consultation::where('status', 'en_cours')
                    ->where(function ($q) use ($user) {
                        $q->where('patient_id', $user->id)
                          ->orWhere('doctor_id', $user->id);
                    })->exists();

                if ($hasActiveConsultation) {
                    // Maintien actif sans coupure : prolongation dynamique de 30 minutes
                    if (! $accessToken->expires_at || $accessToken->expires_at->isPast() || $accessToken->expires_at->diffInMinutes(now()) < 15) {
                        $accessToken->forceFill([
                            'expires_at' => now()->addMinutes(30),
                        ])->save();
                    }

                    return true;
                }
            }

            return $isValid;
        });
    }
}
