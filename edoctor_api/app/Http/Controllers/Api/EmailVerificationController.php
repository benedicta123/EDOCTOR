<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class EmailVerificationController extends Controller
{
    public const OTP_EXPIRATION_MINUTES = 15;

    /**
     * Génère et expédie un code OTP de vérification d'email pour l'utilisateur.
     */
    public static function sendVerificationOtp(User $user): ?string
    {
        $otp = sprintf('%06d', random_int(100000, 999999));
        $cacheKey = "email_verification:{$user->email}";

        Cache::put($cacheKey, [
            'otp_hash' => Hash::make($otp),
            'attempts' => 0,
            'created_at' => Carbon::now()->toIso8601String(),
        ], now()->addMinutes(self::OTP_EXPIRATION_MINUTES));

        try {
            \App\Services\BrevoMailService::send(
                $user->email,
                $user->name,
                'Confirmation de votre adresse email - eDoctor',
                "Bonjour {$user->name},\n\nBienvenue sur eDoctor ! Votre code de confirmation d'adresse email est : {$otp}\n\nCe code expire dans " . self::OTP_EXPIRATION_MINUTES . " minutes.\n\nL'équipe eDoctor Santé Numérique."
            );
        } catch (\Throwable $e) {
            Log::warning("Impossible d'envoyer l'email de vérification à {$user->email} : " . $e->getMessage());
        }

        Log::info("Code de vérification email pour {$user->email} : {$otp}");

        return (app()->environment('local', 'testing') || config('app.debug')) ? $otp : null;
    }

    /**
     * POST /api/email/verify
     * Vérifie le code OTP à 6 chiffres et passe email_verified_at à now().
     */
    public function verify(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'string', 'email'],
            'otp' => ['required', 'string', 'size:6'],
        ]);

        $email = strtolower(trim($validated['email']));
        $user = User::where('email', $email)->first();

        if (! $user) {
            return response()->json([
                'success' => false,
                'message' => 'Aucun compte associé à cette adresse email.',
            ], 404);
        }

        if ($user->hasVerifiedEmail()) {
            return response()->json([
                'success' => true,
                'message' => 'Votre adresse email est déjà vérifiée.',
                'user' => $user,
            ]);
        }

        $cacheKey = "email_verification:{$email}";
        $data = Cache::get($cacheKey);

        if (! $data) {
            return response()->json([
                'success' => false,
                'message' => 'Code de vérification expiré ou introuvable. Veuillez demander un nouveau code.',
            ], 422);
        }

        if (! Hash::check($validated['otp'], $data['otp_hash'])) {
            $attempts = ($data['attempts'] ?? 0) + 1;
            $data['attempts'] = $attempts;
            Cache::put($cacheKey, $data, now()->addMinutes(self::OTP_EXPIRATION_MINUTES));

            $maxAttempts = 5;
            $remaining = max(0, $maxAttempts - $attempts);

            if ($attempts >= 3 && $remaining > 0) {
                $msg = "Code incorrect. Attention : il ne vous reste que {$remaining} tentative" . ($remaining > 1 ? 's' : '') . " avant blocage temporaire.";
            } elseif ($remaining === 0) {
                Cache::forget($cacheKey);
                return response()->json([
                    'success' => false,
                    'message' => 'Trop de tentatives erronées. Le code a été invalidé. Veuillez en demander un nouveau.',
                ], 429);
            } else {
                $msg = "Code de vérification incorrect.";
            }

            return response()->json([
                'success' => false,
                'message' => $msg,
                'attempts_left' => $remaining,
                'warning' => $attempts >= 3,
            ], 422);
        }

        // Succès : validation de l'adresse email
        Cache::forget($cacheKey);
        $user->forceFill([
            'email_verified_at' => now(),
        ])->save();

        return response()->json([
            'success' => true,
            'message' => 'Félicitations ! Votre adresse email a été vérifiée avec succès.',
            'user' => $user->fresh(),
        ]);
    }

    /**
     * POST /api/email/resend
     * Renvoie un nouveau code OTP de vérification.
     */
    public function resend(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'string', 'email'],
        ]);

        $email = strtolower(trim($validated['email']));
        $user = User::where('email', $email)->first();

        if (! $user) {
            return response()->json([
                'success' => true,
                'message' => 'Si cette adresse email existe, un nouveau code vous a été envoyé.',
            ]);
        }

        if ($user->hasVerifiedEmail()) {
            return response()->json([
                'success' => true,
                'message' => 'Votre adresse email est déjà vérifiée.',
            ]);
        }

        $debugOtp = self::sendVerificationOtp($user);

        $response = [
            'success' => true,
            'message' => 'Un nouveau code de vérification à 6 chiffres a été envoyé à votre adresse email.',
        ];

        if ($debugOtp) {
            $response['debug_otp'] = $debugOtp;
        }

        return response()->json($response);
    }
}
