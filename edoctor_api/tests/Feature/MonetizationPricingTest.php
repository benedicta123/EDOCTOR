<?php

namespace Tests\Feature;

use App\Models\Consultation;
use App\Models\Hospital;
use App\Models\Medication;
use App\Models\Order;
use App\Models\Pharmacy;
use App\Models\PharmacyStock;
use App\Models\User;
use App\Services\MonetizationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MonetizationPricingTest extends TestCase
{
    use RefreshDatabase;

    public function test_monetization_service_consultation_pricing(): void
    {
        $hospital = Hospital::create([
            'name' => 'Clinique Saint-Joseph',
            'address' => 'Lomé, Togo',
            'official_email' => 'contact@saint-joseph.tg',
            'phone' => '+228 22 20 00 00',
            'license_number' => 'MS-CLINIC-001',
            'status' => 'verifie',
            'consultation_fee' => 4500.0,
        ]);

        $doctor = User::factory()->create([
            'role' => 'doctor',
            'hospital_id' => $hospital->id,
            'consultation_fee' => null,
        ]);

        $pricing = MonetizationService::calculateConsultationPricing($hospital, $doctor);

        $this->assertEquals(4500.0, $pricing['consultation_fee']);
        $this->assertEquals(450.0, $pricing['edoctor_fee']);
        $this->assertEquals(4950.0, $pricing['total_amount']);
        $this->assertEquals(4500.0, $pricing['hospital_share']);
    }

    public function test_monetization_service_delivery_pricing(): void
    {
        // 1.5 km (forfait de base <= 2 km = 500 FCFA)
        $short = MonetizationService::calculateDeliveryPricing(1.5);
        $this->assertEquals(500.0, $short['delivery_fee']);
        $this->assertEquals(375.0, $short['courier_share']);
        $this->assertEquals(125.0, $short['edoctor_share']);

        // 5.0 km (forfait 2 km = 500 + 3 km sup à 150 = 950 FCFA)
        // Split : 75% coursier = round(950 * 0.75) = 713 FCFA, eDoctor = 237 FCFA
        $medium = MonetizationService::calculateDeliveryPricing(5.0);
        $this->assertEquals(950.0, $medium['delivery_fee']);
        $this->assertEquals(713.0, $medium['courier_share']);
        $this->assertEquals(237.0, $medium['edoctor_share']);
    }

    public function test_monetization_service_order_pricing(): void
    {
        // Commande avec retrait sur place (sans livraison) : Médicaments 3000 F + eDoctor 150 F = 3150 F
        $noDelivery = MonetizationService::calculateOrderPricing(3000.0, false, 0.0);
        $this->assertEquals(3000.0, $noDelivery['items_amount']);
        $this->assertEquals(3000.0, $noDelivery['pharmacy_share']);
        $this->assertEquals(150.0, $noDelivery['edoctor_fee']);
        $this->assertEquals(0.0, $noDelivery['delivery_fee']);
        $this->assertEquals(3150.0, $noDelivery['total_amount']);

        // Commande avec livraison 5 km (frais livraison 950 F) : Total 3000 + 150 + 950 = 4100 F
        $withDelivery = MonetizationService::calculateOrderPricing(3000.0, true, 5.0);
        $this->assertEquals(3000.0, $withDelivery['items_amount']);
        $this->assertEquals(3000.0, $withDelivery['pharmacy_share']);
        $this->assertEquals(150.0, $withDelivery['edoctor_order_fee']);
        $this->assertEquals(950.0, $withDelivery['delivery_fee']);
        $this->assertEquals(4100.0, $withDelivery['total_amount']);
    }

    public function test_order_quote_api_endpoint(): void
    {
        $patient = User::factory()->create(['role' => 'patient']);
        $pharmacyUser = User::factory()->create(['role' => 'pharmacist']);
        $pharmacy = Pharmacy::create([
            'name' => 'Grande Pharmacie de Lomé',
            'address' => 'Boulevard Circulaire, Lomé',
            'phone' => '+228 22 21 00 00',
            'email' => 'contact@gpl.tg',
            'license_number' => 'PH-2026-001',
            'status' => 'verifie',
            'owner_id' => $pharmacyUser->id,
            'latitude' => 6.1375,
            'longitude' => 1.2125,
        ]);

        $medication = Medication::create([
            'name' => 'Paracétamol 1g',
            'category' => 'Antalgique',
            'form' => 'Comprimé',
            'dosage' => '1000mg',
            'price' => 1200.0,
            'requires_prescription' => false,
            'is_active' => true,
        ]);

        PharmacyStock::create([
            'pharmacy_id' => $pharmacy->id,
            'medication_id' => $medication->id,
            'quantity' => 10,
            'price' => 1200.0,
        ]);

        $response = $this->actingAs($patient, 'sanctum')->postJson('/api/orders/quote', [
            'pharmacy_id' => $pharmacy->id,
            'items' => [
                ['medication_id' => $medication->id, 'quantity' => 2],
            ],
            'with_delivery' => true,
            'delivery_distance_km' => 4.0, // 500 + 2*150 = 800
        ]);

        $response->assertOk();
        $response->assertJson([
            'items_amount' => 2400.0,
            'pharmacy_share' => 2400.0,
            'edoctor_order_fee' => 150.0,
            'delivery_fee' => 800.0,
            'total_amount' => 3350.0,
        ]);
    }

    public function test_delivery_quote_api_endpoint(): void
    {
        $patient = User::factory()->create(['role' => 'patient']);

        $response = $this->actingAs($patient, 'sanctum')->postJson('/api/deliveries/quote', [
            'distance_km' => 6.0, // 500 + 4*150 = 1100
        ]);

        $response->assertOk();
        $response->assertJson([
            'distance_km' => 6.0,
            'delivery_fee' => 1100.0,
            'courier_share' => 825.0,
            'edoctor_share' => 275.0,
        ]);
    }

    public function test_consultation_store_and_pay_splits_correctly(): void
    {
        $hospital = Hospital::create([
            'name' => 'Hôpital de Référence',
            'address' => 'Lomé, Togo',
            'official_email' => 'direction@hopital-ref.tg',
            'phone' => '+228 22 25 10 10',
            'license_number' => 'MS-REF-001',
            'status' => 'verifie',
            'consultation_fee' => 3500.0,
        ]);

        $doctor = User::factory()->create([
            'role' => 'doctor',
            'hospital_id' => $hospital->id,
            'specialty' => 'Généraliste',
        ]);
        $patient = User::factory()->create(['role' => 'patient']);

        // 1. Enregistrement de la téléconsultation
        $createRes = $this->actingAs($patient, 'sanctum')->postJson('/api/consultations', [
            'doctor_id' => $doctor->id,
            'scheduled_at' => now()->addDay()->toDateTimeString(),
            'notes' => 'Consultation test monétisation',
        ]);

        $createRes->assertCreated();
        $consultationId = $createRes->json('id');

        $this->assertDatabaseHas('consultations', [
            'id' => $consultationId,
            'consultation_fee' => 3500.0,
            'edoctor_fee' => 350.0,
            'total_amount' => 3850.0,
            'payment_status' => 'en_attente',
        ]);

        // 2. Paiement du montant total par le patient
        $payRes = $this->actingAs($patient, 'sanctum')->postJson("/api/consultations/{$consultationId}/pay", [
            'payment_method' => 'mobile_money',
            'transaction_ref' => 'FLZ-TEST-9988',
        ]);

        $payRes->assertOk();

        $this->assertDatabaseHas('consultations', [
            'id' => $consultationId,
            'payment_status' => 'paye',
        ]);

        $this->assertDatabaseHas('payments', [
            'consultation_id' => $consultationId,
            'amount' => 3850.0,
            'partner_share' => 3500.0,
            'edoctor_fee' => 350.0,
            'courier_share' => 0.0,
            'status' => 'confirme',
            'transaction_ref' => 'FLZ-TEST-9988',
        ]);
    }

    public function test_order_store_creates_accurate_monetization_split(): void
    {
        $patient = User::factory()->create(['role' => 'patient']);
        $pharmacyUser = User::factory()->create(['role' => 'pharmacist']);
        $pharmacy = Pharmacy::create([
            'name' => 'Pharmacie de Bé',
            'address' => 'Bé Marché, Lomé',
            'phone' => '+228 22 22 11 00',
            'email' => 'contact@ph-be.tg',
            'license_number' => 'PH-BE-002',
            'status' => 'verifie',
            'owner_id' => $pharmacyUser->id,
            'latitude' => 6.1280,
            'longitude' => 1.2350,
        ]);

        $medication = Medication::create([
            'name' => 'Amoxicilline 500mg',
            'category' => 'Antibiotique',
            'form' => 'Gélule',
            'dosage' => '500mg',
            'price' => 2000.0,
            'requires_prescription' => false,
            'is_active' => true,
        ]);

        PharmacyStock::create([
            'pharmacy_id' => $pharmacy->id,
            'medication_id' => $medication->id,
            'quantity' => 10,
            'price' => 2000.0,
        ]);

        $response = $this->actingAs($patient, 'sanctum')->postJson('/api/orders', [
            'pharmacy_id' => $pharmacy->id,
            'payment_method' => 'mobile_money',
            'items' => [
                ['medication_id' => $medication->id, 'quantity' => 1],
            ],
            'with_delivery' => true,
            'delivery_address' => 'Quartier Tokoin, Lomé',
            'delivery_distance_km' => 3.0, // 500 + 1*150 = 650. Courier = 488 (round(650*0.75)), eDoctor margin = 162.
        ]);

        $response->assertCreated();
        $orderId = $response->json('id');

        $this->assertDatabaseHas('orders', [
            'id' => $orderId,
            'items_amount' => 2000.0,
            'edoctor_fee' => 150.0,
            'delivery_fee' => 650.0,
            'total_amount' => 2800.0, // 2000 + 150 + 650
        ]);

        $this->assertDatabaseHas('deliveries', [
            'order_id' => $orderId,
            'distance_km' => 3.0,
            'delivery_fee' => 650.0,
            'courier_share' => 488.0,
            'edoctor_share' => 162.0,
        ]);

        $this->assertDatabaseHas('payments', [
            'order_id' => $orderId,
            'amount' => 2800.0,
            'partner_share' => 2000.0, // 100% to pharmacy
            'edoctor_fee' => 312.0,   // 150 F order fee + 162 F delivery margin
            'courier_share' => 488.0, // 75% delivery to courier
            'status' => 'en_attente',
        ]);
    }

    public function test_doctor_gets_only_nearby_in_stock_medications_by_default(): void
    {
        $hospital = Hospital::create([
            'name' => 'CHU Tokoin',
            'address' => 'Boulevard du 13 Janvier, Lomé',
            'latitude' => 6.1375,
            'longitude' => 1.2125,
            'license_number' => 'CHU-001',
            'official_email' => 'contact@chu-tokoin.tg',
            'phone' => '+228 22 21 00 00',
            'status' => 'verifie',
        ]);

        $doctor = User::factory()->create([
            'role' => 'doctor',
            'hospital_id' => $hospital->id,
        ]);
        $patient = User::factory()->create(['role' => 'patient']);

        $consultation = Consultation::create([
            'doctor_id' => $doctor->id,
            'patient_id' => $patient->id,
            'status' => 'en_cours',
            'scheduled_at' => now(),
            'reference_code' => 'CNS-TEST-99',
            'consultation_fee' => 3000.0,
            'edoctor_fee' => 300.0,
            'total_amount' => 3300.0,
        ]);

        // Pharmacie 1 : Très proche (distance ~1 km de l'hôpital)
        $pharmacyNear = Pharmacy::create([
            'name' => 'Pharmacie Populaire',
            'address' => 'Tokoin, Lomé',
            'latitude' => 6.1400,
            'longitude' => 1.2150,
            'status' => 'verifie',
            'phone' => '+228 90 00 11 22',
            'email' => 'populaire@ph.tg',
            'license_number' => 'PH-01',
            'owner_id' => User::factory()->create(['role' => 'pharmacist'])->id,
        ]);

        // Pharmacie 2 : Lointaine (> 35 km)
        $pharmacyFar = Pharmacy::create([
            'name' => 'Pharmacie Maritime Sud',
            'address' => 'Aného, Togo',
            'latitude' => 6.2300,
            'longitude' => 1.6000,
            'status' => 'verifie',
            'phone' => '+228 90 00 33 44',
            'email' => 'sud@ph.tg',
            'license_number' => 'PH-02',
            'owner_id' => User::factory()->create(['role' => 'pharmacist'])->id,
        ]);

        // Médicament A : En stock dans la pharmacie proche
        $medA = Medication::create([
            'name' => 'Amoxicilline 500mg',
            'category' => 'Antibiotique',
            'dosage' => '500mg',
            'form' => 'Gélule',
            'requires_prescription' => true,
        ]);
        PharmacyStock::create([
            'pharmacy_id' => $pharmacyNear->id,
            'medication_id' => $medA->id,
            'quantity' => 12,
            'price' => 1500.0,
        ]);

        // Médicament B : En stock uniquement dans la pharmacie lointaine
        $medB = Medication::create([
            'name' => 'Ciprofloxacine 500mg',
            'category' => 'Antibiotique',
            'dosage' => '500mg',
            'form' => 'Comprimé',
            'requires_prescription' => true,
        ]);
        PharmacyStock::create([
            'pharmacy_id' => $pharmacyFar->id,
            'medication_id' => $medB->id,
            'quantity' => 8,
            'price' => 2500.0,
        ]);

        // Médicament C : En rupture totale (stock = 0 partout)
        $medC = Medication::create([
            'name' => 'Azithromycine 250mg',
            'category' => 'Antibiotique',
            'dosage' => '250mg',
            'form' => 'Comprimé',
            'requires_prescription' => true,
        ]);

        // 1. Appel par défaut : in_stock_only = true (Règle DG)
        $responseDefault = $this->actingAs($doctor, 'sanctum')
            ->getJson("/api/consultations/{$consultation->id}/medications");

        $responseDefault->assertOk();
        $responseDefault->assertJsonPath('in_stock_only', true);
        $dataDefault = $responseDefault->json('medications');

        // Seul le Médicament A doit être renvoyé car disponible à proximité (< 15 km)
        $this->assertCount(1, $dataDefault);
        $this->assertEquals($medA->id, $dataDefault[0]['id']);
        $this->assertTrue($dataDefault[0]['in_stock']);
        $this->assertEquals(1, $dataDefault[0]['nearby_pharmacies_count']);
        $this->assertEquals('Pharmacie Populaire', $dataDefault[0]['nearest_pharmacy']);

        // 2. Appel avec in_stock_only = false (Mode déblocage / Tout le catalogue)
        $responseAll = $this->actingAs($doctor, 'sanctum')
            ->getJson("/api/consultations/{$consultation->id}/medications?in_stock_only=0");

        $responseAll->assertOk();
        $responseAll->assertJsonPath('in_stock_only', false);
        $dataAll = $responseAll->json('medications');

        // Les 3 médicaments sont renvoyés, Médicament A en premier (car en stock)
        $this->assertCount(3, $dataAll);
        $this->assertEquals($medA->id, $dataAll[0]['id']);
        $this->assertTrue($dataAll[0]['in_stock']);
        $this->assertFalse($dataAll[1]['in_stock']);
        $this->assertFalse($dataAll[2]['in_stock']);
    }
}
