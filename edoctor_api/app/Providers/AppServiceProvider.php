<?php

namespace App\Providers;

use App\Models\Pharmacy;
use App\Policies\PatientDossierPolicy;
use App\Policies\PharmacyPolicy;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;

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
    }
}
