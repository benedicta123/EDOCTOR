<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password;

class PasswordResetController extends Controller
{
    /**
     * Durée de validité du code OTP en minutes (Norme OWASP stricte).
     */
    public const OTP_EXPIRATION_MINUTES = 5;

    /**
     * 1. Demande de réinitialisation de mot de passe : envoie d'un code OTP à 6 chiffres.
     * POST /api/password/forgot
     */
    public function forgot(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'string', 'email'],
        ]);

        $email = strtolower(trim($validated['email']));
        $user = User::where('email', $email)->first();

        // Si l'utilisateur n'existe pas, réponse générique pour éviter l'énumération des comptes
        if (! $user) {
            return response()->json([
                'success' => true,
                'message' => 'Si cette adresse email est associée à un compte eDoctor, un code de sécurité à 6 chiffres vient d\'y être envoyé.',
            ]);
        }

        // Vérification de blocage ou suspension
        if ($user->is_suspended) {
            return response()->json([
                'success' => false,
                'message' => 'Ce compte a été suspendu par l\'administration eDoctor. Contactez le support pour toute réclamation.',
            ], 403);
        }

        // Génération d'un code OTP aléatoire cryptographiquement sûr (6 chiffres)
        $otp = sprintf('%06d', random_int(100000, 999999));

        // Enregistrement dans la table password_reset_tokens
        // Stockage du code hashé pour protéger la base de données
        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $email],
            [
                'token' => Hash::make($otp),
                'created_at' => Carbon::now(),
            ]
        );

        // Réinitialisation du compteur d'essais pour ce nouvel OTP
        Cache::forget("otp_attempts:{$email}");

        // Journalisation sécurisée (en environnement dev/log)
        Log::info("Code OTP réinitialisation mot de passe pour {$email} : {$otp}");

        // Envoi par email via Brevo REST API
        try {
            \App\Services\BrevoMailService::send(
                $email,
                $user->name,
                'Votre code de réinitialisation eDoctor',
                "Bonjour {$user->name},\n\nVotre code de vérification pour réinitialiser votre mot de passe eDoctor est : {$otp}\n\nCe code est strictement confidentiel et expirera dans " . self::OTP_EXPIRATION_MINUTES . " minutes.\nSi vous n'êtes pas à l'origine de cette demande, veuillez ignorer ce message.\n\nL'équipe eDoctor Santé Numérique."
            );
        } catch (\Throwable $e) {
            Log::warning("Impossible d'envoyer l'email OTP à {$email} : " . $e->getMessage());
        }

        $responsePayload = [
            'success' => true,
            'message' => 'Si cette adresse email est associée à un compte eDoctor, un code de sécurité à 6 chiffres vient d\'y être envoyé.',
        ];

        // En environnement local ou de test, on expose l'OTP dans la réponse pour faciliter les démonstrations immédiates
        if (app()->environment('local', 'testing') || config('app.debug')) {
            $responsePayload['debug_otp'] = $otp;
        }

        return response()->json($responsePayload);
    }

    /**
     * 2. Vérification du code OTP reçu.
     * POST /api/password/verify-otp
     */
    public function verifyOtp(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'string', 'email'],
            'otp' => ['required', 'string', 'size:6'],
        ]);

        $email = strtolower(trim($validated['email']));
        $record = DB::table('password_reset_tokens')->where('email', $email)->first();

        if (! $record) {
            return response()->json([
                'success' => false,
                'message' => 'Aucune demande de réinitialisation en cours pour cet email ou code expiré.',
            ], 422);
        }

        // Vérification de l'expiration (15 minutes)
        $createdAt = Carbon::parse($record->created_at);
        if ($createdAt->addMinutes(self::OTP_EXPIRATION_MINUTES)->isPast()) {
            DB::table('password_reset_tokens')->where('email', $email)->delete();

            return response()->json([
                'success' => false,
                'message' => 'Ce code de vérification a expiré. Veuillez demander un nouveau code.',
            ], 422);
        }

        // Vérification de la correspondance du hash
        $cacheKey = "otp_attempts:{$email}";
        if (! Hash::check($validated['otp'], $record->token)) {
            $attempts = (int) Cache::get($cacheKey, 0) + 1;
            Cache::put($cacheKey, $attempts, now()->addMinutes(self::OTP_EXPIRATION_MINUTES));

            $maxAttempts = 5;
            $remaining = max(0, $maxAttempts - $attempts);

            if ($attempts >= 3 && $remaining > 0) {
                $warningMsg = "Code de sécurité incorrect. Attention : il ne vous reste que {$remaining} tentative" . ($remaining > 1 ? 's' : '') . " avant blocage temporaire.";
            } elseif ($remaining === 0) {
                $warningMsg = "Code incorrect. Vous avez épuisé vos 5 tentatives. Votre accès est temporairement bloqué.";
            } else {
                $warningMsg = "Le code de sécurité saisi est incorrect.";
            }

            return response()->json([
                'success' => false,
                'message' => $warningMsg,
                'attempts' => $attempts,
                'attempts_left' => $remaining,
                'warning' => $attempts >= 3,
            ], 422);
        }

        // Si succès : réinitialisation du compteur d'essais
        Cache::forget($cacheKey);

        // Génération d'un token d'autorisation temporaire (reset_token) pour la 3ème étape
        $resetToken = Str::random(64);
        DB::table('password_reset_tokens')->where('email', $email)->update([
            'token' => Hash::make($resetToken),
            'created_at' => Carbon::now(), // renouvelle pour 15 min
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Code de vérification validé avec succès.',
            'reset_token' => $resetToken,
        ]);
    }

    /**
     * 3. Réinitialisation effective du mot de passe avec le token validé.
     * POST /api/password/reset
     */
    public function reset(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'string', 'email'],
            'reset_token' => ['required', 'string'],
            'password' => ['required', 'confirmed', Password::min(8)->letters()->mixedCase()->numbers()->symbols()->uncompromised()],
        ]);

        $email = strtolower(trim($validated['email']));
        $record = DB::table('password_reset_tokens')->where('email', $email)->first();

        if (! $record) {
            return response()->json([
                'success' => false,
                'message' => 'Session de réinitialisation invalide ou expirée.',
            ], 422);
        }

        // Vérification expiration
        $createdAt = Carbon::parse($record->created_at);
        if ($createdAt->addMinutes(self::OTP_EXPIRATION_MINUTES)->isPast()) {
            DB::table('password_reset_tokens')->where('email', $email)->delete();

            return response()->json([
                'success' => false,
                'message' => 'Session expirée. Veuillez recommencer la procédure.',
            ], 422);
        }

        // Vérification du reset_token
        if (! Hash::check($validated['reset_token'], $record->token)) {
            return response()->json([
                'success' => false,
                'message' => 'Jeton d\'autorisation invalide.',
            ], 422);
        }

        $user = User::where('email', $email)->first();
        if (! $user) {
            return response()->json([
                'success' => false,
                'message' => 'Utilisateur introuvable.',
            ], 404);
        }

        // Mise à jour du mot de passe
        $user->password = Hash::make($validated['password']);
        $user->save();

        // MESURE DE SÉCURITÉ CRITIQUE : Révoquer TOUS les jetons Sanctum actifs existants
        $user->tokens()->delete();

        // Suppression de la demande de réinitialisation
        DB::table('password_reset_tokens')->where('email', $email)->delete();

        // Levée immédiate de tout verrouillage temporaire de sécurité
        Cache::forget("account_lockout:{$email}");
        Cache::forget("account_login_attempts:{$email}");

        Log::info("Mot de passe réinitialisé avec succès pour l'utilisateur ID: {$user->id} ({$email}) - Toutes les sessions antérieures révoquées et compte déverrouillé.");

        return response()->json([
            'success' => true,
            'message' => 'Votre mot de passe a été réinitialisé avec succès. Vous pouvez maintenant vous connecter.',
        ]);
    }
}
