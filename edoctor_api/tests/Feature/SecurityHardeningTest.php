<?php

namespace Tests\Feature;

use App\Models\Consultation;
use App\Models\Hospital;
use App\Models\LabRequest;
use App\Models\LabRequestItem;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use Tests\TestCase;

class SecurityHardeningTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        RateLimiter::clear('login');
        RateLimiter::clear('otp-verify');
        RateLimiter::clear('otp-send');
        RateLimiter::clear('register');
    }

    /**
     * Test 1 : Anti-Brute-Force sur Login (bloqué à la 6e tentative avec 429 Too Many Requests)
     */
    public function test_login_rate_limiting_blocks_brute_force(): void
    {
        $user = User::factory()->create([
            'email' => 'victim@edoctor.tg',
            'password' => bcrypt('RealPassword123'),
        ]);

        for ($i = 1; $i <= 5; $i++) {
            $res = $this->postJson('/api/login', [
                'email' => 'victim@edoctor.tg',
                'password' => 'WrongPass_' . $i,
            ]);
            $this->assertEquals(422, $res->status());
        }

        // 6e tentative : doit être bloquée avec HTTP 429
        $blockedRes = $this->postJson('/api/login', [
            'email' => 'victim@edoctor.tg',
            'password' => 'WrongPass_6',
        ]);

        $blockedRes->assertStatus(429);
        $blockedRes->assertJsonStructure(['message']);
    }

    /**
     * Test 2 : Anti-Brute-Force sur l'OTP de réinitialisation de mot de passe (bloqué à la 6e tentative)
     */
    public function test_otp_verify_rate_limiting_blocks_brute_force(): void
    {
        for ($i = 1; $i <= 5; $i++) {
            $res = $this->postJson('/api/password/verify-otp', [
                'email' => 'victim@edoctor.tg',
                'otp' => '00000' . $i,
            ]);
            $this->assertNotEquals(429, $res->status());
        }

        $blockedRes = $this->postJson('/api/password/verify-otp', [
            'email' => 'victim@edoctor.tg',
            'otp' => '999999',
        ]);

        $blockedRes->assertStatus(429);
    }

    /**
     * Test 3 : Blocage absolu des contournements de paiement manuel
     */
    public function test_unauthenticated_or_patient_cannot_confirm_payment(): void
    {
        $patient = User::factory()->create(['role' => 'patient']);
        $payment = Payment::create([
            'method' => 'mobile_money',
            'amount' => 5000.0,
            'partner_share' => 4500.0,
            'edoctor_fee' => 500.0,
            'status' => 'en_attente',
            'transaction_ref' => 'TEST-001',
        ]);

        // Appel sans jeton : 401 Unauthorized
        $guestRes = $this->postJson("/api/payments/{$payment->id}/confirm", [
            'transaction_ref' => 'HACKED-123',
        ]);
        $guestRes->assertStatus(401);

        // Appel en tant que patient simple : 403 Forbidden
        $patientRes = $this->actingAs($patient, 'sanctum')->postJson("/api/payments/{$payment->id}/confirm", [
            'transaction_ref' => 'HACKED-123',
        ]);
        $patientRes->assertStatus(403);

        $this->assertEquals('en_attente', $payment->fresh()->status);
    }

    /**
     * Test 4 : Stockage privé et validation stricte MIME des résultats d'analyses
     */
    public function test_lab_results_enforce_mime_whitelist_and_private_storage(): void
    {
        Storage::fake('local');
        Storage::fake('public');

        $doctor = User::factory()->create(['role' => 'doctor']);
        $patient = User::factory()->create(['role' => 'patient']);

        $consultation = Consultation::create([
            'doctor_id' => $doctor->id,
            'patient_id' => $patient->id,
            'status' => 'en_cours',
            'scheduled_at' => now(),
            'reference_code' => 'CNS-2610-TEST-01',
            'consultation_fee' => 3000.0,
            'edoctor_fee' => 300.0,
            'total_amount' => 3300.0,
            'payment_status' => 'paye',
        ]);

        $labRequest = LabRequest::create([
            'consultation_id' => $consultation->id,
            'doctor_id' => $doctor->id,
            'patient_id' => $patient->id,
            'clinical_notes' => 'Bilan sanguin complet',
            'status' => 'prescrit',
        ]);

        // 1. Rejet d'un fichier exécutable / script interdit
        $fakeScript = UploadedFile::fake()->create('malicious.php', 100, 'application/x-php');
        $badRes = $this->actingAs($patient, 'sanctum')->postJson("/api/lab-requests/{$labRequest->id}/results", [
            'file' => $fakeScript,
        ]);
        $badRes->assertStatus(422);

        // 2. Acceptation d'un document PDF légitime
        $validPdf = UploadedFile::fake()->create('analyse_sang.pdf', 500, 'application/pdf');
        $goodRes = $this->actingAs($patient, 'sanctum')->postJson("/api/lab-requests/{$labRequest->id}/results", [
            'file' => $validPdf,
            'patient_notes' => 'Voici mes résultats du CHU',
        ]);

        $goodRes->assertStatus(201);

        $resultRecord = $labRequest->results()->first();
        $this->assertNotNull($resultRecord);

        // Vérification que le fichier est stocké sur le disque LOCAL PRIVÉ et NON sur le disque PUBLIC
        $rawPath = $resultRecord->getRawOriginal('file_path');
        Storage::disk('local')->assertExists($rawPath);
        Storage::disk('public')->assertMissing($rawPath);

        // Vérification de la signature HMAC générée par l'accesseur
        $signedUrl = $resultRecord->file_path;
        $this->assertStringContainsString('signature=', $signedUrl);
        $this->assertStringContainsString('expires=', $signedUrl);

        // 3. Accès sans signature ou altéré : 403 Forbidden
        $tamperedUrl = preg_replace('/signature=[a-f0-9]+/', 'signature=tamperedbadhash', $signedUrl);
        $tamperedRes = $this->get($tamperedUrl);
        $tamperedRes->assertStatus(403);

        // 4. Accès avec signature authentique : 200 OK
        $legitRes = $this->get($signedUrl);
        $legitRes->assertOk();
    }

    /**
     * Test 5 : Avertissement après 3 tentatives erronées d'OTP (2 tentatives restantes)
     */
    public function test_otp_warning_triggered_after_three_failed_attempts(): void
    {
        $user = User::factory()->create(['email' => 'patient.test@edoctor.tg']);
        $otp = '123456';
        \Illuminate\Support\Facades\DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => 'patient.test@edoctor.tg'],
            ['token' => \Illuminate\Support\Facades\Hash::make($otp), 'created_at' => now()]
        );
        \Illuminate\Support\Facades\Cache::forget('otp_attempts:patient.test@edoctor.tg');

        // Essais 1 et 2 : erreur standard
        for ($i = 1; $i <= 2; $i++) {
            $res = $this->postJson('/api/password/verify-otp', [
                'email' => 'patient.test@edoctor.tg',
                'otp' => '00000' . $i,
            ]);
            $res->assertStatus(422);
            $res->assertJson([
                'success' => false,
                'warning' => false,
            ]);
        }

        // Essai 3 : ALERTE explicite indiquant qu'il ne reste que 2 tentatives
        $res3 = $this->postJson('/api/password/verify-otp', [
            'email' => 'patient.test@edoctor.tg',
            'otp' => '000003',
        ]);
        $res3->assertStatus(422);
        $res3->assertJson([
            'success' => false,
            'warning' => true,
            'attempts_left' => 2,
        ]);
        $this->assertStringContainsString('2 tentatives', $res3->json('message'));

        // Essai 4 : ALERTE explicite indiquant qu'il ne reste qu'une seule tentative
        $res4 = $this->postJson('/api/password/verify-otp', [
            'email' => 'patient.test@edoctor.tg',
            'otp' => '000004',
        ]);
        $res4->assertStatus(422);
        $res4->assertJson([
            'success' => false,
            'warning' => true,
            'attempts_left' => 1,
        ]);
        $this->assertStringContainsString('1 tentative', $res4->json('message'));
    }

    /**
     * Test 6 : Anti-Spam Inscriptions limité à 3 créations par minute par IP
     */
    public function test_register_rate_limiting_blocks_at_fourth_attempt(): void
    {
        RateLimiter::clear('register');

        // 3 inscriptions consécutives autorisées
        for ($i = 1; $i <= 3; $i++) {
            $res = $this->postJson('/api/register', [
                'name' => "Patient $i",
                'email' => "patient_burst_{$i}@edoctor.tg",
                'password' => 'Ed0ctor2026!#UltraSecure',
                'password_confirmation' => 'Ed0ctor2026!#UltraSecure',
                'phone' => "+228 90 00 00 0{$i}",
            ]);
            $res->assertStatus(201);
        }

        // 4e inscription bloquée avec 429
        $blockedRes = $this->postJson('/api/register', [
            'name' => 'Patient 4',
            'email' => 'patient_burst_4@edoctor.tg',
            'password' => 'Ed0ctor2026!#UltraSecure',
            'password_confirmation' => 'Ed0ctor2026!#UltraSecure',
            'phone' => '+228 90 00 00 04',
        ]);
        $blockedRes->assertStatus(429);
        $this->assertStringContainsString('maximum 3', $blockedRes->json('message'));
    }

    /**
     * Test 7 : Règle stricte limitant à 1 seul compte par numéro de téléphone
     */
    public function test_cannot_register_multiple_accounts_with_same_phone(): void
    {
        RateLimiter::clear('register');
        $phone = '+228 91 23 45 67';

        // 1er compte : OK
        $res1 = $this->postJson('/api/register', [
            'name' => 'Patient Un',
            'email' => 'patient1_samephone@edoctor.tg',
            'password' => 'Ed0ctor2026!#UltraSecure',
            'password_confirmation' => 'Ed0ctor2026!#UltraSecure',
            'phone' => $phone,
        ]);
        $res1->assertStatus(201);

        // 2e compte avec le même téléphone (même format différent) : REFUSÉ (422)
        $res2 = $this->postJson('/api/register', [
            'name' => 'Patient Deux',
            'email' => 'patient2_samephone@edoctor.tg',
            'password' => 'Ed0ctor2026!#UltraSecure',
            'password_confirmation' => 'Ed0ctor2026!#UltraSecure',
            'phone' => '91234567', // Format sans indicatif, même numéro
        ]);
        $res2->assertStatus(422);
        $res2->assertJsonValidationErrors(['phone']);
        $this->assertStringContainsString('déjà associé à un compte', $res2->json('errors.phone.0'));
    }

    /**
     * Test 8 : Vérification d'adresse email par OTP (email_verified_at)
     */
    public function test_email_verification_flow_with_otp(): void
    {
        RateLimiter::clear('register');
        RateLimiter::clear('otp-verify');

        // 1. Inscription : compte créé avec email non vérifié
        $registerRes = $this->postJson('/api/register', [
            'name' => 'Ablam Togo',
            'email' => 'ablam.togo@edoctor.tg',
            'password' => 'Ed0ctor2026!#UltraSecure',
            'password_confirmation' => 'Ed0ctor2026!#UltraSecure',
            'phone' => '+228 92 11 22 33',
        ]);

        $registerRes->assertStatus(201);
        $registerRes->assertJson(['is_email_verified' => false]);
        $debugOtp = $registerRes->json('debug_otp');
        $this->assertNotNull($debugOtp);

        $user = User::where('email', 'ablam.togo@edoctor.tg')->first();
        $this->assertNull($user->email_verified_at);

        // 2. Mauvais code : rejeté 422
        $badVerify = $this->postJson('/api/email/verify', [
            'email' => 'ablam.togo@edoctor.tg',
            'otp' => '000000',
        ]);
        $badVerify->assertStatus(422);

        // 3. Bon code OTP : validé 200 et email_verified_at mis à jour
        $goodVerify = $this->postJson('/api/email/verify', [
            'email' => 'ablam.togo@edoctor.tg',
            'otp' => $debugOtp,
        ]);
        $goodVerify->assertOk();
        $goodVerify->assertJson(['success' => true]);

        $this->assertNotNull($user->fresh()->email_verified_at);
    }

    /**
     * Test 9 : Double Authentification (2FA) obligatoire pour Praticiens et Administrateurs
     */
    public function test_two_factor_authentication_required_for_doctors_and_admins(): void
    {
        RateLimiter::clear('login');
        RateLimiter::clear('otp-verify');

        $doctor = User::factory()->create([
            'email' => 'dr.mensah@chu-campus.tg',
            'password' => bcrypt('DocteurPass123!'),
            'role' => 'doctor',
        ]);

        // 1. Le praticien tente de se connecter : bloqué au palier 1 avec demande de 2FA
        $loginRes = $this->postJson('/api/login', [
            'email' => 'dr.mensah@chu-campus.tg',
            'password' => 'DocteurPass123!',
        ]);

        $loginRes->assertOk();
        $loginRes->assertJson([
            'requires_2fa' => true,
            'role' => 'doctor',
        ]);
        $this->assertArrayNotHasKey('token', $loginRes->json()); // Pas de token d'accès direct

        $twoFactorToken = $loginRes->json('two_factor_token');
        $debugCode = $loginRes->json('debug_2fa_code');
        $this->assertNotNull($twoFactorToken);
        $this->assertNotNull($debugCode);

        // 2. Validation avec mauvais code 2FA : échec 422
        $bad2Fa = $this->postJson('/api/login/verify-2fa', [
            'two_factor_token' => $twoFactorToken,
            'code' => '999999',
        ]);
        $bad2Fa->assertStatus(422);

        // 3. Validation avec bon code 2FA : succès 200 et délivrance du jeton d'accès Sanctum
        $good2Fa = $this->postJson('/api/login/verify-2fa', [
            'two_factor_token' => $twoFactorToken,
            'code' => $debugCode,
        ]);

        $good2Fa->assertOk();
        $good2Fa->assertJsonStructure(['token', 'user']);
        $this->assertEquals($doctor->id, $good2Fa->json('user.id'));
    }

    /**
     * Test 10 : Chiffrement des données de santé au repos dans la base de données
     */
    public function test_health_data_is_encrypted_at_rest_in_database(): void
    {
        $sensitiveHistory = "Allergie grave aux céphalosporines, diabète type 2, antécédent AVC 2024.";
        $sensitiveDiagnosis = "Infection respiratoire aiguë basse avec détresse modérée.";

        $patient = User::factory()->create([
            'role' => 'patient',
            'medical_history_summary' => $sensitiveHistory,
        ]);

        $doctor = User::factory()->create(['role' => 'doctor']);

        $consultation = Consultation::create([
            'doctor_id' => $doctor->id,
            'patient_id' => $patient->id,
            'status' => 'terminee',
            'scheduled_at' => now(),
            'reference_code' => 'CNS-2610-ENCRYPT',
            'consultation_fee' => 4000.0,
            'edoctor_fee' => 400.0,
            'total_amount' => 4400.0,
            'payment_status' => 'paye',
            'diagnosis' => $sensitiveDiagnosis,
        ]);

        // 1. Vérification en base de données BRUTE (SQL direct) : les données sensibles NE sont PAS en clair
        $rawPatientHistory = \Illuminate\Support\Facades\DB::table('users')
            ->where('id', $patient->id)
            ->value('medical_history_summary');

        $this->assertNotEquals($sensitiveHistory, $rawPatientHistory);
        $this->assertStringNotContainsString('céphalosporines', $rawPatientHistory);
        $this->assertStringNotContainsString('diabète', $rawPatientHistory);

        $rawConsultationDiagnosis = \Illuminate\Support\Facades\DB::table('consultations')
            ->where('id', $consultation->id)
            ->value('diagnosis');

        $this->assertNotEquals($sensitiveDiagnosis, $rawConsultationDiagnosis);
        $this->assertStringNotContainsString('Infection respiratoire', $rawConsultationDiagnosis);

        // 2. Vérification via Eloquent : le déchiffrement est transparent et fidèle pour l'application
        $this->assertEquals($sensitiveHistory, $patient->fresh()->medical_history_summary);
        $this->assertEquals($sensitiveDiagnosis, $consultation->fresh()->diagnosis);
    }

    /**
     * Test 11 : Politique stricte de complexité des mots de passe (minuscules, majuscules, chiffres, symboles, non compromis)
     */
    public function test_strict_password_complexity_rules_are_enforced(): void
    {
        RateLimiter::clear('register');

        // 1. Mot de passe sans majuscules/symboles -> REJETÉ
        $weakRes = $this->postJson('/api/register', [
            'name' => 'Test Faible',
            'email' => 'weak.pass@edoctor.tg',
            'password' => 'simplepass123',
            'password_confirmation' => 'simplepass123',
        ]);
        $weakRes->assertStatus(422);
        $weakRes->assertJsonValidationErrors(['password']);

        // 2. Mot de passe trop court (< 8 caractères) -> REJETÉ
        $shortRes = $this->postJson('/api/register', [
            'name' => 'Test Court',
            'email' => 'short.pass@edoctor.tg',
            'password' => 'P@ss1',
            'password_confirmation' => 'P@ss1',
        ]);
        $shortRes->assertStatus(422);
        $shortRes->assertJsonValidationErrors(['password']);

        // 3. Mot de passe compromis / fuite publique (ex. Password123!) -> REJETÉ
        $leakedRes = $this->postJson('/api/register', [
            'name' => 'Test Compromis',
            'email' => 'leaked.pass@edoctor.tg',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
        ]);
        $leakedRes->assertStatus(422);
        $leakedRes->assertJsonValidationErrors(['password']);
    }

    /**
     * Test 12 : Présence systématique des en-têtes HTTP de sécurité défensifs
     */
    public function test_http_security_headers_are_present_on_all_responses(): void
    {
        $response = $this->getJson('/api/medications');

        $response->assertStatus(200);
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'SAMEORIGIN');
        $response->assertHeader('X-XSS-Protection', '1; mode=block');
        $response->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->assertHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(self)');
        $this->assertStringContainsString("default-src 'none'", (string) $response->headers->get('Content-Security-Policy'));
    }

    /**
     * Test 13 : Verrouillage temporaire de compte (Account Lockout après 10 échecs consécutifs)
     */
    public function test_account_lockout_after_10_consecutive_failed_attempts(): void
    {
        $user = User::factory()->create([
            'email' => 'lockout.target@edoctor.tg',
            'password' => bcrypt('RealStrongPass2026!#'),
            'role' => 'patient',
        ]);

        RateLimiter::clear('login');
        Cache::forget('account_lockout:lockout.target@edoctor.tg');
        Cache::forget('account_login_attempts:lockout.target@edoctor.tg');

        // Tentatives 1 à 6 : échecs 422 standard venant d'adresses IP distinctes
        for ($i = 1; $i <= 6; $i++) {
            $res = $this->withServerVariables(['REMOTE_ADDR' => "10.0.0.{$i}"])->postJson('/api/login', [
                'email' => 'lockout.target@edoctor.tg',
                'password' => 'WrongPass_' . $i,
            ]);
            $res->assertStatus(422);
            $this->assertStringNotContainsString('Attention, il vous reste', (string) $res->json('errors.email.0'));
        }

        // Tentative 7 : alerte qu'il reste 3 tentatives
        $res7 = $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.7'])->postJson('/api/login', [
            'email' => 'lockout.target@edoctor.tg',
            'password' => 'WrongPass_7',
        ]);
        $res7->assertStatus(422);
        $this->assertStringContainsString('il vous reste 3 tentative(s)', (string) $res7->json('errors.email.0'));

        // Tentatives 8 et 9
        for ($i = 8; $i <= 9; $i++) {
            $res = $this->withServerVariables(['REMOTE_ADDR' => "10.0.0.{$i}"])->postJson('/api/login', [
                'email' => 'lockout.target@edoctor.tg',
                'password' => 'WrongPass_' . $i,
            ]);
            $res->assertStatus(422);
        }

        // 10e tentative : VERROUILLAGE IMMÉDIAT (HTTP 423 Locked)
        $res10 = $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.10'])->postJson('/api/login', [
            'email' => 'lockout.target@edoctor.tg',
            'password' => 'WrongPass_10',
        ]);
        $res10->assertStatus(423);
        $this->assertStringContainsString('temporairement verrouillé', $res10->json('message'));
        $this->assertNotNull($res10->json('locked_until'));

        // 11e tentative (même avec le bon mot de passe et une nouvelle IP !) : bloquée par le verrouillage actif
        $res11 = $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.11'])->postJson('/api/login', [
            'email' => 'lockout.target@edoctor.tg',
            'password' => 'RealStrongPass2026!#',
        ]);
        $res11->assertStatus(423);
        $this->assertStringContainsString('temporairement verrouillé', $res11->json('message'));

        // Déverrouillage après expiration ou réinitialisation
        Cache::forget('account_lockout:lockout.target@edoctor.tg');

        // Connexion réussie maintenant que le compte est déverrouillé
        $successRes = $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.12'])->postJson('/api/login', [
            'email' => 'lockout.target@edoctor.tg',
            'password' => 'RealStrongPass2026!#',
        ]);
        $successRes->assertStatus(200);
        $this->assertNotNull($successRes->json('token'));
    }

    /**
     * Test 14 : Le paiement simulé direct est formellement interdit en production
     */
    public function test_direct_payment_simulation_forbidden_in_production(): void
    {
        $patient = User::factory()->create(['role' => 'patient']);
        $doctor = User::factory()->create(['role' => 'doctor']);
        $consultation = Consultation::factory()->create([
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'status' => 'en_attente',
            'total_amount' => 5000,
        ]);

        // Simuler l'environnement production
        app()->detectEnvironment(fn () => 'production');

        $response = $this->actingAs($patient)->postJson("/api/consultations/{$consultation->id}/pay", [
            'payment_method' => 'mobile_money',
        ]);

        // Doit être rejeté avec 403 Forbidden
        $response->assertStatus(403);
        $this->assertStringContainsString('interdit en environnement de production', $response->json('message'));

        // Revenir à l'environnement testing
        app()->detectEnvironment(fn () => 'testing');
    }

    /**
     * Test 15 : Le webhook FedaPay rejette la simulation et exige le secret en production
     */
    public function test_fedapay_webhook_strictly_hardened_in_production(): void
    {
        $patient = User::factory()->create(['role' => 'patient']);
        $doctor = User::factory()->create(['role' => 'doctor']);
        $consultation = Consultation::factory()->create([
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'status' => 'en_attente',
            'total_amount' => 5000,
            'payment_status' => 'en_attente',
        ]);

        // 1. En environnement production SANS clé secrète configurée : doit renvoyer 500 Alerte Sécurité
        app()->detectEnvironment(fn () => 'production');
        config(['services.fedapay.webhook_secret' => '']);

        $resNoSecret = $this->postJson('/api/webhooks/fedapay', [
            'name' => 'transaction.approved',
            'entity' => [
                'id' => 99999,
                'status' => 'approved',
                'custom_metadata' => ['consultation_id' => $consultation->id],
            ],
        ]);
        $resNoSecret->assertStatus(500);

        // 2. En production avec secret configuré mais signature invalide ou absente : rejeté 401
        config(['services.fedapay.webhook_secret' => 'super_secret_fedapay_key_2026']);
        config(['services.fedapay.secret_key' => 'sk_live_dummy']);

        $resBadSign = $this->postJson('/api/webhooks/fedapay', [
            'name' => 'transaction.approved',
            'entity' => [
                'id' => 99999,
                'status' => 'approved',
                'custom_metadata' => ['consultation_id' => $consultation->id],
            ],
        ], [
            'X-FedaPay-Signature' => 'invalid_signature_forged',
        ]);
        $resBadSign->assertStatus(401);

        // 3. En production avec simulation forgée sans FedaPay configuré : rejeté
        config(['services.fedapay.secret_key' => '']); // non configuré
        $resSimForbidden = $this->postJson('/api/webhooks/fedapay', [
            'name' => 'transaction.approved',
            'entity' => [
                'id' => 99999,
                'status' => 'approved',
                'custom_metadata' => ['consultation_id' => $consultation->id],
            ],
        ], [
            'X-FedaPay-Signature' => 'super_secret_fedapay_key_2026',
        ]);
        $this->assertTrue(in_array($resSimForbidden->status(), [403, 500]));

        // Revenir à l'environnement testing
        app()->detectEnvironment(fn () => 'testing');
    }
}


