<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * POST /api/register et POST /api/patients/register
     * Inscription dédiée exclusivement aux patients.
     * Le rôle est systématiquement forcé à "patient".
     * Les soignants (médecins, infirmiers) sont enregistrés par les hôpitaux.
     */
    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)->letters()->mixedCase()->numbers()->symbols()->uncompromised()],
            'phone' => ['nullable', 'string', 'max:30'],
            'date_of_birth' => ['nullable', 'date', 'before:today'],
            'address' => ['nullable', 'string', 'max:255'],
            'medical_history_summary' => ['nullable', 'string', 'max:2000'],
        ]);

        // Règle stricte d'unicité : un seul compte autorisé par numéro de téléphone
        if (! empty($validated['phone'])) {
            $rawPhone = trim($validated['phone']);
            $digitsOnly = preg_replace('/[^0-9]/', '', $rawPhone);
            $suffix8 = strlen($digitsOnly) >= 8 ? substr($digitsOnly, -8) : $digitsOnly;

            $existingCount = User::whereNotNull('phone')
                ->where(function ($q) use ($rawPhone, $digitsOnly, $suffix8) {
                    $q->where('phone', $rawPhone)
                      ->orWhere('phone', $digitsOnly)
                      ->orWhereRaw("REPLACE(REPLACE(REPLACE(phone, ' ', ''), '-', ''), '.', '') LIKE ?", ["%{$suffix8}%"]);
                })->count();

            if ($existingCount >= 1) {
                throw ValidationException::withMessages([
                    'phone' => ['Ce numéro de téléphone est déjà associé à un compte eDoctor. Un seul compte est autorisé par numéro.'],
                ]);
            }
        }

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'role' => 'patient',
            'phone' => $validated['phone'] ?? null,
            'date_of_birth' => $validated['date_of_birth'] ?? null,
            'address' => $validated['address'] ?? null,
            'medical_history_summary' => $validated['medical_history_summary'] ?? null,
        ]);

        $token = $user->createAccessToken('api-token')->plainTextToken;

        // Expédition automatique du code de vérification d'email
        $debugOtp = EmailVerificationController::sendVerificationOtp($user);

        $responsePayload = [
            'user' => $user,
            'token' => $token,
            'is_email_verified' => false,
            'message' => 'Compte créé avec succès. Un code de vérification à 6 chiffres a été envoyé à votre adresse email.',
        ];

        if ($debugOtp) {
            $responsePayload['debug_otp'] = $debugOtp;
        }

        return response()->json($responsePayload, 201);
    }

    public const MAX_LOGIN_ATTEMPTS = 10;
    public const LOCKOUT_DURATION_MINUTES = 15;

    /**
     * POST /api/login
     */
    public function login(Request $request)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
        ]);

        $normalizedEmail = strtolower(trim($validated['email']));
        $lockoutKey = "account_lockout:{$normalizedEmail}";
        $attemptsKey = "account_login_attempts:{$normalizedEmail}";

        // 1. Vérifier si le compte est temporairement verrouillé suite à 10 échecs consécutifs
        if (Cache::has($lockoutKey)) {
            $lockedUntil = Cache::get($lockoutKey);
            $remainingSeconds = max(1, now()->diffInSeconds($lockedUntil, false));
            $remainingMinutes = (int) ceil($remainingSeconds / 60);

            return response()->json([
                'message' => "Ce compte est temporairement verrouillé pour des raisons de sécurité suite à 10 tentatives infructueuses. Veuillez réessayer dans {$remainingMinutes} minute(s) ou réinitialiser votre mot de passe.",
                'locked_until' => $lockedUntil instanceof \Carbon\CarbonInterface ? $lockedUntil->toIso8601String() : (string) $lockedUntil,
                'retry_after_seconds' => $remainingSeconds,
            ], 423);
        }

        $user = User::where('email', $normalizedEmail)->first();

        // 2. Vérification des identifiants & gestion du compteur d'échecs
        if (! $user || ! Hash::check($validated['password'], $user->password)) {
            $attempts = (int) Cache::get($attemptsKey, 0) + 1;
            Cache::put($attemptsKey, $attempts, now()->addMinutes(self::LOCKOUT_DURATION_MINUTES));

            if ($attempts >= self::MAX_LOGIN_ATTEMPTS) {
                $lockedUntil = now()->addMinutes(self::LOCKOUT_DURATION_MINUTES);
                Cache::put($lockoutKey, $lockedUntil, $lockedUntil);
                Cache::forget($attemptsKey);

                if ($user) {
                    try {
                        \App\Services\BrevoMailService::send(
                            $user->email,
                            $user->name,
                            'Alerte Sécurité eDoctor : Compte temporairement verrouillé',
                            "Bonjour {$user->name},\n\nVotre compte eDoctor a été temporairement verrouillé pendant 15 minutes suite à 10 tentatives de connexion infructueuses consécutives.\n\nSi vous n'êtes pas à l'origine de ces tentatives, nous vous recommandons vivement de réinitialiser votre mot de passe dès que possible.\n\nL'équipe Sécurité eDoctor."
                        );
                    } catch (\Throwable $e) {
                        Log::warning("Impossible d'envoyer l'alerte de verrouillage à {$user->email} : " . $e->getMessage());
                    }
                }

                return response()->json([
                    'message' => "Ce compte a été temporairement verrouillé pendant 15 minutes suite à 10 tentatives de connexion infructueuses.",
                    'locked_until' => $lockedUntil->toIso8601String(),
                    'retry_after_seconds' => self::LOCKOUT_DURATION_MINUTES * 60,
                ], 423);
            }

            $remaining = self::MAX_LOGIN_ATTEMPTS - $attempts;
            $warning = $attempts >= 7
                ? " Attention, il vous reste {$remaining} tentative(s) avant le verrouillage temporaire de votre compte pour 15 minutes."
                : "";

            throw ValidationException::withMessages([
                'email' => ["Identifiants incorrects.{$warning}"],
            ]);
        }

        // Connexion réussie : réinitialisation immédiate du compteur d'échecs
        Cache::forget($attemptsKey);
        Cache::forget($lockoutKey);

        if ($user->is_suspended) {
            $reason = $user->suspension_reason ? " : " . $user->suspension_reason : "";
            return response()->json([
                'message' => "Ce compte utilisateur a été suspendu par l'administration eDoctor{$reason}. Veuillez contacter le support de régulation.",
            ], 403);
        }

        if ($user->isPharmacist()) {
            $user->load('pharmacy');
        }

        // ─── Double Authentification (2FA / MFA) pour Praticiens & Administrateurs ───
        $privilegedRoles = ['doctor', 'admin', 'pharmacist'];
        $twoFactorEnabled = config('auth.two_factor_enabled', true);

        if ($twoFactorEnabled && in_array($user->role, $privilegedRoles)) {
            $twoFactorCode = sprintf('%06d', random_int(100000, 999999));
            $twoFactorToken = Str::random(64);

            Cache::put("2fa_pending:{$twoFactorToken}", [
                'user_id' => $user->id,
                'code_hash' => Hash::make($twoFactorCode),
                'attempts' => 0,
            ], now()->addMinutes(5));

            try {
                \App\Services\BrevoMailService::send(
                    $user->email,
                    $user->name,
                    'Code de sécurité 2FA eDoctor',
                    "Bonjour {$user->name},\n\nVotre code d'authentification à deux facteurs (2FA) eDoctor pour valider votre connexion est : {$twoFactorCode}\n\nCe code expire dans 5 minutes.\n\nL'équipe Sécurité eDoctor."
                );
            } catch (\Throwable $e) {
                Log::warning("Impossible d'envoyer le code 2FA à {$user->email} : " . $e->getMessage());
            }

            Log::info("Code 2FA généré pour {$user->email} : {$twoFactorCode}");

            $atPos = strpos($user->email, '@');
            $maskLen = max(1, $atPos - 3);

            $payload = [
                'requires_2fa' => true,
                'two_factor_token' => $twoFactorToken,
                'email_masked' => Str::mask($user->email, '*', 2, $maskLen),
                'role' => $user->role,
                'message' => 'Double authentification requise. Un code de sécurité à 6 chiffres a été envoyé à votre adresse email professionnelle.',
            ];

            if (app()->environment('local', 'testing') || config('app.debug')) {
                $payload['debug_2fa_code'] = $twoFactorCode;
            }

            return response()->json($payload, 200);
        }

        $token = $user->createAccessToken('api-token')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ]);
    }

    /**
     * POST /api/login/verify-2fa
     * Validation du second facteur (2FA) pour Praticiens et Administrateurs.
     */
    public function verifyTwoFactor(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'two_factor_token' => ['required', 'string'],
            'code' => ['required', 'string', 'size:6'],
        ]);

        $cacheKey = "2fa_pending:{$validated['two_factor_token']}";
        $data = Cache::get($cacheKey);

        if (! $data) {
            return response()->json([
                'success' => false,
                'message' => 'Session 2FA expirée ou invalide. Veuillez vous reconnecter.',
            ], 422);
        }

        if (! Hash::check($validated['code'], $data['code_hash'])) {
            $attempts = ($data['attempts'] ?? 0) + 1;
            $data['attempts'] = $attempts;
            Cache::put($cacheKey, $data, now()->addMinutes(5));

            $remaining = max(0, 5 - $attempts);
            if ($attempts >= 3 && $remaining > 0) {
                $msg = "Code 2FA incorrect. Attention : il ne vous reste que {$remaining} tentative" . ($remaining > 1 ? 's' : '') . " avant annulation.";
            } elseif ($remaining === 0) {
                Cache::forget($cacheKey);
                return response()->json([
                    'success' => false,
                    'message' => 'Nombre maximal de tentatives 2FA dépassé. Session annulée.',
                ], 429);
            } else {
                $msg = 'Code de sécurité 2FA incorrect.';
            }

            return response()->json([
                'success' => false,
                'message' => $msg,
                'attempts_left' => $remaining,
                'warning' => $attempts >= 3,
            ], 422);
        }

        Cache::forget($cacheKey);
        $user = User::findOrFail($data['user_id']);

        if ($user->isPharmacist()) {
            $user->load('pharmacy');
        }

        $token = $user->createAccessToken('api-token')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
            'message' => 'Authentification 2FA validée avec succès.',
        ]);
    }

    /**
     * POST /api/logout
     * Nécessite d'être authentifié (middleware auth:sanctum).
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Déconnecté.']);
    }

    /**
     * GET /api/me
     * Nécessite d'être authentifié (middleware auth:sanctum).
     */
    public function me(Request $request)
    {
        return response()->json($request->user());
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();
        $rules = [
            'name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
        ];

        if ($user->isDoctor()) {
            $rules['specialty'] = ['sometimes', 'string', 'max:255'];
            $rules['license_number'] = ['sometimes', 'string', 'max:255'];
        }

        $user->update($request->validate($rules));

        return response()->json($user->fresh());
    }
}
