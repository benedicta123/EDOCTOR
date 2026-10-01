<?php

namespace Tests\Feature;

use App\Models\Hospital;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class HospitalRegistrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_can_register_hospital_with_super_admin(): void
    {
        $payload = [
            'hospital_name' => 'CHU Sylvanus Olympio',
            'address' => 'Boulevard du 13 Janvier, Lomé',
            'latitude' => 6.1375,
            'longitude' => 1.2125,
            'license_number' => 'MS-TOGO-2026-001',
            'tax_number' => 'NIF-1234567890',
            'official_email' => 'contact@chu-so.tg',
            'hospital_phone' => '+228 22 21 25 01',
            'admin_name' => 'Dr. Koffi Mensah',
            'admin_email' => 'admin@chu-so.tg',
            'password' => 'SecurePass123!',
            'password_confirmation' => 'SecurePass123!',
            'admin_phone' => '+228 90 01 02 03',
        ];

        $response = $this->postJson('/api/hospitals/register', $payload);

        $response->assertStatus(201);
        $response->assertJsonStructure([
            'message',
            'hospital' => ['id', 'name', 'address', 'latitude', 'longitude', 'status'],
            'admin' => ['id', 'name', 'email', 'role', 'hospital_id'],
            'token',
        ]);

        $this->assertDatabaseHas('hospitals', [
            'name' => 'CHU Sylvanus Olympio',
            'official_email' => 'contact@chu-so.tg',
            'latitude' => 6.1375,
            'longitude' => 1.2125,
        ]);

        $this->assertDatabaseHas('users', [
            'email' => 'admin@chu-so.tg',
            'role' => 'admin',
        ]);

        $hospital = Hospital::where('official_email', 'contact@chu-so.tg')->first();
        $admin = User::where('email', 'admin@chu-so.tg')->first();

        $this->assertEquals($hospital->id, $admin->hospital_id);
    }
}
