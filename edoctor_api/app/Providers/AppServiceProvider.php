<?php

namespace App\Providers;

use App\Models\Consultation;
use App\Models\Pharmacy;
use App\Models\User;
use App\Policies\PatientDossierPolicy;
use App\Policies\PharmacyPolicy;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use App\Services\SafeResponseFactory;
use Illuminate\Contracts\Routing\ResponseFactory as ResponseFactoryContract;
use Illuminate\Contracts\View\Factory as ViewFactoryContract;
use Laravel\Sanctum\Sanctum;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Enregistrement d'un ResponseFactory sécurisé contre les erreurs UTF-8
        $this->app->singleton(ResponseFactoryContract::class, function ($app) {
            return new SafeResponseFactory(
                $app[ViewFactoryContract::class],
                $app['redirect']
            );
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Gate::define('viewPatientDossier', [PatientDossierPolicy::class, 'view']);
        Gate::policy(Pharmacy::class, PharmacyPolicy::class);

        // ─── Rate Limiters de Sécurité Anti-Brute-Force & Anti-Abus ─────────
        RateLimiter::for('login', function (Request $request) {
            $key = strtolower((string) $request->input('email', '')) . '|' . $request->ip();
            return Limit::perMinute(5)->by($key)->response(function () {
                return response()->json([
                    'message' => 'Trop de tentatives de connexion. Veuillez patienter 1 minute avant de réessayer.',
                ], 429);
            });
        });

        RateLimiter::for('otp-send', function (Request $request) {
            $key = strtolower((string) $request->input('email', '')) . '|' . $request->ip();
            return Limit::perMinute(3)->by($key)->response(function () {
                return response()->json([
                    'message' => 'Trop de demandes de code. Veuillez patienter 1 minute avant de renouveler.',
                ], 429);
            });
        });

        RateLimiter::for('otp-verify', function (Request $request) {
            $key = strtolower((string) $request->input('email', '')) . '|' . $request->ip();
            return Limit::perMinute(5)->by($key)->response(function () {
                return response()->json([
                    'message' => 'Trop d\'essais de code de sécurité. Veuillez patienter 1 minute avant de réessayer.',
                ], 429);
            });
        });

        RateLimiter::for('register', function (Request $request) {
            return Limit::perMinute(3)->by($request->ip())->response(function () {
                return response()->json([
                    'message' => 'Trop de créations de compte depuis cette adresse IP (maximum 3 par minute). Veuillez patienter.',
                ], 429);
            });
        });

        // Limiteur anti-déni de service / anti-flooding sur les webhooks de paiement
        RateLimiter::for('webhook', function (Request $request) {
            return Limit::perMinute(60)->by($request->ip())->response(function () {
                return response()->json([
                    'error' => 'Trop de requêtes webhook envoyées. Veuillez ralentir.',
                ], 429);
            });
        });

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
