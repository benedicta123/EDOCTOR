<?php

namespace Tests\Feature;

use App\Models\Hospital;
use App\Models\HospitalAppointment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class HospitalAppointmentTest extends TestCase
{
    use RefreshDatabase;

    private Hospital $hospital;
    private User $patient;
    private User $doctor;
    private User $hospitalAdmin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->hospital = Hospital::create([
            'name' => 'Centre Hospitalier Universitaire Sylvanus Olympio',
            'address' => 'Boulevard du 13 Janvier, Lomé',
            'latitude' => 6.1375,
            'longitude' => 1.2125,
            'official_email' => 'contact@chu-so.tg',
            'phone' => '+228 22 21 25 01',
            'license_number' => 'AGR-CHU-2026-001',
            'tax_number' => 'NIF-9988776655',
            'status' => 'verifie',
            'consultation_fee' => 3000.00,
        ]);

        $this->patient = User::factory()->create([
            'role' => 'patient',
            'name' => 'Koffi Mensah',
        ]);

        $this->doctor = User::factory()->create([
            'role' => 'doctor',
            'name' => 'Dr. Eric Lawson',
            'specialty' => 'Cardiologie',
            'hospital_id' => $this->hospital->id,
        ]);

        $this->hospitalAdmin = User::factory()->create([
            'role' => 'hospital_admin',
            'name' => 'Accueil CHU',
            'hospital_id' => $this->hospital->id,
        ]);
    }

    public function test_patient_can_get_hospital_slots(): void
    {
        $response = $this->actingAs($this->patient)
            ->getJson("/api/hospitals/{$this->hospital->id}/slots?date=2026-12-01");

        $response->assertOk()
            ->assertJsonStructure([
                'hospital' => ['id', 'name', 'consultation_fee'],
                'departments',
                'doctors',
                'slots' => [
                    '*' => ['time_slot', 'booked_count', 'available', 'remaining'],
                ],
            ]);
    }

    public function test_patient_can_book_hospital_appointment(): void
    {
        $payload = [
            'hospital_id' => $this->hospital->id,
            'department' => 'Cardiologie',
            'appointment_date' => now()->addDays(2)->toDateString(),
            'time_slot' => '09:00 - 09:30',
            'doctor_id' => $this->doctor->id,
            'reason' => 'Bilan cardiaque de routine et suivi tensionnel',
        ];

        $response = $this->actingAs($this->patient)
            ->postJson('/api/hospital-appointments', $payload);

        $response->assertCreated()
            ->assertJsonPath('appointment.department', 'Cardiologie')
            ->assertJsonPath('appointment.status', 'reserve')
            ->assertJsonPath('appointment.queue_number', 1);

        $this->assertDatabaseHas('hospital_appointments', [
            'hospital_id' => $this->hospital->id,
            'patient_id' => $this->patient->id,
            'doctor_id' => $this->doctor->id,
            'department' => 'Cardiologie',
            'status' => 'reserve',
        ]);
    }

    public function test_reception_can_check_in_and_assign_doctor(): void
    {
        $appointment = HospitalAppointment::create([
            'reference_code' => 'RDV-2611-CHU-TEST',
            'hospital_id' => $this->hospital->id,
            'patient_id' => $this->patient->id,
            'department' => 'Médecine Générale',
            'appointment_date' => now()->toDateString(),
            'time_slot' => '10:00 - 10:30',
            'queue_number' => 1,
            'status' => 'reserve',
            'consultation_fee' => 3000,
        ]);

        $response = $this->actingAs($this->hospitalAdmin)
            ->postJson("/api/hospital-appointments/{$appointment->id}/check-in", [
                'doctor_id' => $this->doctor->id,
            ]);

        $response->assertOk()
            ->assertJsonPath('appointment.status', 'en_attente')
            ->assertJsonPath('appointment.doctor_id', $this->doctor->id);

        $this->assertDatabaseHas('hospital_appointments', [
            'id' => $appointment->id,
            'status' => 'en_attente',
            'doctor_id' => $this->doctor->id,
        ]);
    }

    public function test_doctor_can_call_in_and_complete_consultation(): void
    {
        $appointment = HospitalAppointment::create([
            'reference_code' => 'RDV-2611-CHU-TEST2',
            'hospital_id' => $this->hospital->id,
            'patient_id' => $this->patient->id,
            'doctor_id' => $this->doctor->id,
            'department' => 'Cardiologie',
            'appointment_date' => now()->toDateString(),
            'time_slot' => '10:00 - 10:30',
            'queue_number' => 2,
            'status' => 'en_attente',
            'checked_in_at' => now(),
            'consultation_fee' => 3000,
        ]);

        // 1. Doctor calls patient into office
        $callResponse = $this->actingAs($this->doctor)
            ->postJson("/api/hospital-appointments/{$appointment->id}/call-in");

        $callResponse->assertOk()
            ->assertJsonPath('appointment.status', 'en_consultation');

        // 2. Doctor completes consultation
        $completeResponse = $this->actingAs($this->doctor)
            ->postJson("/api/hospital-appointments/{$appointment->id}/complete", [
                'doctor_notes' => 'Tension 12/8. Rythme sinusal régulier. Traitement reconduit.',
            ]);

        $completeResponse->assertOk()
            ->assertJsonPath('appointment.status', 'termine')
            ->assertJsonPath('appointment.doctor_notes', 'Tension 12/8. Rythme sinusal régulier. Traitement reconduit.');

        $this->assertDatabaseHas('hospital_appointments', [
            'id' => $appointment->id,
            'status' => 'termine',
        ]);
    }
}
