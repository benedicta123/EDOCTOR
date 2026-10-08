<?php

namespace Tests\Feature;

use App\Models\Consultation;
use App\Models\Hospital;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Règle métier : le médecin ne doit être sonné (et ne peut démarrer)
 * qu'une fois la consultation payée par le patient.
 */
class ConsultationPaymentGatingTest extends TestCase
{
    use RefreshDatabase;

    private function makeDoctorAndPatient(): array
    {
        $hospital = Hospital::create([
            'name' => 'CHU Test Paiement',
            'address' => 'Lomé, Togo',
            'official_email' => 'contact@chu-pay.tg',
            'phone' => '+228 22 00 00 00',
            'license_number' => 'MS-PAY-001',
            'status' => 'verifie',
            'consultation_fee' => 3000.0,
        ]);

        $doctor = User::factory()->create(['role' => 'doctor', 'hospital_id' => $hospital->id]);
        $patient = User::factory()->create(['role' => 'patient']);

        return [$doctor, $patient];
    }

    public function test_doctor_does_not_see_unpaid_request_and_no_notification_is_sent(): void
    {
        [$doctor, $patient] = $this->makeDoctorAndPatient();

        $res = $this->actingAs($patient, 'sanctum')->postJson('/api/consultations', [
            'doctor_id' => $doctor->id,
        ]);
        $res->assertCreated();

        $this->assertDatabaseMissing('notifications', [
            'user_id' => $doctor->id,
            'type' => 'consultation_request',
        ]);

        $list = $this->actingAs($doctor, 'sanctum')->getJson('/api/consultations');
        $list->assertOk();
        $this->assertCount(0, $list->json());

        $dashboard = $this->actingAs($doctor, 'sanctum')->getJson('/api/doctor/dashboard');
        $dashboard->assertOk();
        $dashboard->assertJsonPath('pending_consultations', 0);

        // Le patient, lui, voit bien sa demande
        $patientList = $this->actingAs($patient, 'sanctum')->getJson('/api/consultations');
        $this->assertCount(1, $patientList->json());
    }

    public function test_doctor_is_rung_once_fedapay_confirms_payment(): void
    {
        config(['services.fedapay.secret_key' => 'sk_sandbox_test_key_12345']);
        config(['services.fedapay.environment' => 'sandbox']);

        [$doctor, $patient] = $this->makeDoctorAndPatient();

        $consultationId = $this->actingAs($patient, 'sanctum')
            ->postJson('/api/consultations', ['doctor_id' => $doctor->id])
            ->json('id');

        Payment::create([
            'consultation_id' => $consultationId,
            'method' => 'mobile_money',
            'amount' => 3300.0,
            'partner_share' => 3000.0,
            'edoctor_fee' => 300.0,
            'status' => 'en_attente',
            'transaction_ref' => 'trx_gating',
        ]);

        Http::fake([
            'https://sandbox-api.fedapay.com/v1/transactions/555' => Http::response([
                'v1/transaction' => ['id' => 555, 'reference' => 'trx_gating', 'status' => 'approved', 'amount' => 3300],
            ], 200),
        ]);

        $this->actingAs($patient, 'sanctum')
            ->getJson("/api/consultations/{$consultationId}/pay/fedapay/status?transaction_id=555")
            ->assertOk()
            ->assertJsonPath('is_approved', true);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $doctor->id,
            'type' => 'consultation_request',
        ]);

        $list = $this->actingAs($doctor, 'sanctum')->getJson('/api/consultations');
        $this->assertCount(1, $list->json());
        $this->assertSame('en_attente', $list->json('0.status'));
    }

    public function test_doctor_cannot_start_unpaid_consultation(): void
    {
        [$doctor, $patient] = $this->makeDoctorAndPatient();

        $consultation = Consultation::create([
            'doctor_id' => $doctor->id,
            'patient_id' => $patient->id,
            'status' => 'en_attente',
            'consultation_fee' => 3000.0,
            'edoctor_fee' => 300.0,
            'total_amount' => 3300.0,
            'payment_status' => 'en_attente',
        ]);

        $this->actingAs($doctor, 'sanctum')
            ->postJson("/api/consultations/{$consultation->id}/start")
            ->assertStatus(402);

        $this->assertDatabaseHas('consultations', ['id' => $consultation->id, 'status' => 'en_attente']);
    }

    public function test_direct_pay_endpoint_is_refused_when_fedapay_is_configured(): void
    {
        config(['services.fedapay.secret_key' => 'sk_sandbox_test_key_12345']);

        [$doctor, $patient] = $this->makeDoctorAndPatient();

        $consultationId = $this->actingAs($patient, 'sanctum')
            ->postJson('/api/consultations', ['doctor_id' => $doctor->id])
            ->json('id');

        $this->actingAs($patient, 'sanctum')
            ->postJson("/api/consultations/{$consultationId}/pay", ['payment_method' => 'mobile_money'])
            ->assertForbidden();

        $this->assertDatabaseHas('consultations', ['id' => $consultationId, 'payment_status' => 'en_attente']);
    }
}
