<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_password_generates_otp_for_existing_user(): void
    {
        $user = User::factory()->create([
            'email' => 'patient.test@edoctor.tg',
            'password' => Hash::make('AncientSecretPassword123!'),
        ]);

        $response = $this->postJson('/api/password/forgot', [
            'email' => 'patient.test@edoctor.tg',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $this->assertDatabaseHas('password_reset_tokens', [
            'email' => 'patient.test@edoctor.tg',
        ]);
    }

    public function test_verify_otp_and_reset_password_revokes_previous_tokens(): void
    {
        $user = User::factory()->create([
            'email' => 'patient.verify@edoctor.tg',
            'password' => Hash::make('AncientSecretPassword123!'),
        ]);

        // Simule un token Sanctum actif existant
        $oldToken = $user->createToken('old-phone-session')->plainTextToken;
        $this->assertCount(1, $user->tokens);

        // 1. Demande OTP
        $forgotRes = $this->postJson('/api/password/forgot', [
            'email' => 'patient.verify@edoctor.tg',
        ]);
        $forgotRes->assertStatus(200);
        $otp = $forgotRes->json('debug_otp');
        $this->assertNotEmpty($otp);

        // 2. Vérification OTP
        $verifyRes = $this->postJson('/api/password/verify-otp', [
            'email' => 'patient.verify@edoctor.tg',
            'otp' => $otp,
        ]);
        $verifyRes->assertStatus(200)
            ->assertJson(['success' => true]);
        $resetToken = $verifyRes->json('reset_token');
        $this->assertNotEmpty($resetToken);

        // 3. Réinitialisation mot de passe
        $resetRes = $this->postJson('/api/password/reset', [
            'email' => 'patient.verify@edoctor.tg',
            'reset_token' => $resetToken,
            'password' => 'NewSecurePassword2026!',
            'password_confirmation' => 'NewSecurePassword2026!',
        ]);
        $resetRes->assertStatus(200)
            ->assertJson(['success' => true]);

        // Vérification que le mot de passe a changé
        $user->refresh();
        $this->assertTrue(Hash::check('NewSecurePassword2026!', $user->password));

        // Vérification critique : les anciens tokens d'accès ont bien été révoqués
        $this->assertCount(0, $user->tokens);
    }
}
