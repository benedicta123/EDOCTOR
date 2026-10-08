<?php

namespace Tests\Feature;

use App\Models\Consultation;
use App\Models\Hospital;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class FedaPayPaymentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.fedapay.secret_key' => 'sk_sandbox_test_key_12345']);
        config(['services.fedapay.environment' => 'sandbox']);
    }

    public function test_initiate_consultation_payment_creates_fedapay_transaction(): void
    {
        $hospital = Hospital::create([
            'name' => 'CHU Sylvanus Olympio',
            'address' => 'Lomé, Togo',
            'official_email' => 'contact@chu-so.tg',
            'phone' => '+228 22 21 25 01',
            'license_number' => 'MS-CHU-001',
            'status' => 'verifie',
            'consultation_fee' => 3000.0,
        ]);

        $doctor = User::factory()->create([
            'role' => 'doctor',
            'hospital_id' => $hospital->id,
            'consultation_fee' => null,
        ]);

        $patient = User::factory()->create(['role' => 'patient', 'phone' => '+228 90 12 34 56']);

        $consultation = Consultation::create([
            'doctor_id' => $doctor->id,
            'patient_id' => $patient->id,
            'status' => 'en_attente',
            'scheduled_at' => now()->addDay(),
            'reference_code' => 'CNS-FEDA-01',
            'consultation_fee' => 3000.0,
            'edoctor_fee' => 300.0,
            'total_amount' => 3300.0,
            'payment_status' => 'en_attente',
        ]);

        // Mock FedaPay REST API
        Http::fake([
            'https://sandbox-api.fedapay.com/v1/transactions' => Http::response([
                'v1/transaction' => [
                    'id' => 78910,
                    'reference' => 'trx_fp_test_78910',
                    'amount' => 3300,
                    'status' => 'pending',
                ],
            ], 200),
            'https://sandbox-api.fedapay.com/v1/transactions/78910/token' => Http::response([
                'v1/token' => [
                    'token' => 'tok_sandbox_abc123',
                    'url' => 'https://sandbox-checkout.fedapay.com/tok_sandbox_abc123',
                ],
            ], 200),
        ]);

        $res = $this->actingAs($patient, 'sanctum')->postJson("/api/consultations/{$consultation->id}/pay/fedapay");

        $res->assertOk();
        $res->assertJson([
            'success' => true,
            'consultation_id' => $consultation->id,
            'transaction_id' => 78910,
            'checkout_url' => 'https://sandbox-checkout.fedapay.com/tok_sandbox_abc123',
            'amount' => 3300.0,
        ]);

        $this->assertDatabaseHas('payments', [
            'consultation_id' => $consultation->id,
            'amount' => 3300.0,
            'partner_share' => 3000.0,
            'edoctor_fee' => 300.0,
            'status' => 'en_attente',
            'transaction_ref' => 'trx_fp_test_78910',
        ]);
    }

    public function test_verify_consultation_payment_approves_when_fedapay_approved(): void
    {
        $patient = User::factory()->create(['role' => 'patient']);
        $doctor = User::factory()->create(['role' => 'doctor']);

        $consultation = Consultation::create([
            'doctor_id' => $doctor->id,
            'patient_id' => $patient->id,
            'status' => 'en_attente',
            'scheduled_at' => now(),
            'reference_code' => 'CNS-FEDA-02',
            'consultation_fee' => 3000.0,
            'edoctor_fee' => 300.0,
            'total_amount' => 3300.0,
            'payment_status' => 'en_attente',
        ]);

        Payment::create([
            'consultation_id' => $consultation->id,
            'method' => 'mobile_money',
            'amount' => 3300.0,
            'partner_share' => 3000.0,
            'edoctor_fee' => 300.0,
            'status' => 'en_attente',
            'transaction_ref' => '78910',
        ]);

        Http::fake([
            'https://sandbox-api.fedapay.com/v1/transactions/78910' => Http::response([
                'v1/transaction' => [
                    'id' => 78910,
                    'reference' => 'trx_fp_test_78910',
                    'status' => 'approved',
                    'amount' => 3300,
                ],
            ], 200),
        ]);

        $res = $this->actingAs($patient, 'sanctum')->getJson("/api/consultations/{$consultation->id}/pay/fedapay/status");

        $res->assertOk();
        $res->assertJson([
            'success' => true,
            'status' => 'paye',
            'is_approved' => true,
        ]);

        $this->assertDatabaseHas('consultations', [
            'id' => $consultation->id,
            'payment_status' => 'paye',
        ]);

        $this->assertDatabaseHas('payments', [
            'consultation_id' => $consultation->id,
            'status' => 'confirme',
        ]);
    }

    public function test_fedapay_webhook_approves_consultation(): void
    {
        $patient = User::factory()->create(['role' => 'patient']);
        $doctor = User::factory()->create(['role' => 'doctor']);

        $consultation = Consultation::create([
            'doctor_id' => $doctor->id,
            'patient_id' => $patient->id,
            'status' => 'en_attente',
            'scheduled_at' => now(),
            'reference_code' => 'CNS-FEDA-03',
            'consultation_fee' => 4000.0,
            'edoctor_fee' => 400.0,
            'total_amount' => 4400.0,
            'payment_status' => 'en_attente',
        ]);

        $payment = Payment::create([
            'consultation_id' => $consultation->id,
            'method' => 'mobile_money',
            'amount' => 4400.0,
            'partner_share' => 4000.0,
            'edoctor_fee' => 400.0,
            'status' => 'en_attente',
            'transaction_ref' => 'FP-99999',
        ]);

        $webhookPayload = [
            'name' => 'transaction.approved',
            'entity' => [
                'id' => 99999,
                'reference' => 'FP-WEBHOOK-99999',
                'status' => 'approved',
                'amount' => 4400,
                'custom_metadata' => [
                    'consultation_id' => $consultation->id,
                ],
            ],
        ];

        $res = $this->postJson('/api/webhooks/fedapay', $webhookPayload);

        $res->assertOk();

        $this->assertDatabaseHas('consultations', [
            'id' => $consultation->id,
            'payment_status' => 'paye',
        ]);

        $this->assertDatabaseHas('payments', [
            'id' => $payment->id,
            'status' => 'confirme',
            'transaction_ref' => 'FP-WEBHOOK-99999',
        ]);
    }
}
