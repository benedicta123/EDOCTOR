<?php

namespace Tests\Feature;

use App\Models\Consultation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConsultationVideoJoinTest extends TestCase
{
    use RefreshDatabase;

    private string $keyPath;

    protected function setUp(): void
    {
        parent::setUp();

        // Environnement OpenSSL AVANT tout usage (cf. JaasService).
        \App\Services\JaasService::ensureOpensslEnvironment();

        // Clé RSA statique réservée aux tests (tests/Fixtures, jamais la prod).
        $this->keyPath = tempnam(sys_get_temp_dir(), 'jaas-test-').'.pem';
        copy(base_path('tests/Fixtures/jaas-test-key.pem'), $this->keyPath);

        config([
            'jaas.app_id' => 'test-app-id',
            'jaas.key_id' => 'test-app-id/123e4567-e89b-42d3-a456-426614174000',
            'jaas.domain' => '8x8.vc',
            'jaas.token_ttl' => 600,
        ]);
    }

    protected function tearDown(): void
    {
        @unlink($this->keyPath);
        parent::tearDown();
    }

    private function consultation(string $status = 'en_cours'): array
    {
        $doctor = User::factory()->create(['role' => 'doctor']);
        $patient = User::factory()->create(['role' => 'patient']);
        $consultation = Consultation::create([
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'status' => $status,
        ]);

        return [$doctor, $patient, $consultation];
    }

    public function test_doctor_and_patient_receive_same_room_and_jwt(): void
    {
        [$doctor, $patient, $consultation] = $this->consultation();

        $asDoctor = $this->actingAs($doctor)
            ->postJson("/api/consultations/{$consultation->id}/join")
            ->assertOk()
            ->json();

        $asPatient = $this->actingAs($patient)
            ->postJson("/api/consultations/{$consultation->id}/join")
            ->assertOk()
            ->json();

        foreach ([$asDoctor, $asPatient] as $payload) {
            $this->assertSame('https://8x8.vc/test-app-id', $payload['server_url']);
            $this->assertNotEmpty($payload['room_name']);
            $this->assertNotEmpty($payload['jwt']);
            $this->assertNotEmpty($payload['expires_at']);
            $this->assertCount(3, explode('.', $payload['jwt']));
        }

        // Même salle des deux côtés, sans donnée patient dedans.
        $this->assertSame($asDoctor['room_name'], $asPatient['room_name']);
        $this->assertStringNotContainsStringIgnoringCase(
            $patient->name, $asPatient['room_name']
        );
        $this->assertStringStartsWith('edoctor-', $asPatient['room_name']);
    }

    public function test_non_participant_is_forbidden(): void
    {
        [, , $consultation] = $this->consultation();
        $intruder = User::factory()->create(['role' => 'patient']);

        $this->actingAs($intruder)
            ->postJson("/api/consultations/{$consultation->id}/join")
            ->assertForbidden();
    }

    public function test_closed_consultation_is_rejected(): void
    {
        [$doctor, , $consultation] = $this->consultation('terminee');

        $this->actingAs($doctor)
            ->postJson("/api/consultations/{$consultation->id}/join")
            ->assertStatus(422);
    }

    public function test_missing_jaas_config_returns_503(): void
    {
        config(['jaas.private_key_path' => '/chemin/inexistant.pem']);
        [$doctor, , $consultation] = $this->consultation();

        $this->actingAs($doctor)
            ->postJson("/api/consultations/{$consultation->id}/join")
            ->assertStatus(503);
    }

    public function test_short_key_id_is_accepted(): void
    {
        // Les ID de clé JaaS sont courts (ex. {APP_ID}/3a0565) : acceptés.
        config(['jaas.key_id' => 'test-app-id/fc9c6b']);
        [$doctor, , $consultation] = $this->consultation();

        $this->actingAs($doctor)
            ->postJson("/api/consultations/{$consultation->id}/join")
            ->assertOk()
            ->assertJsonStructure(
                ['server_url', 'domain', 'app_id', 'room_name', 'jwt', 'expires_at']
            );
    }
}
