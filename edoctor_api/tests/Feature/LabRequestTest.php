<?php

namespace Tests\Feature;

use App\Models\Consultation;
use App\Models\Hospital;
use App\Models\LabRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class LabRequestTest extends TestCase
{
    use RefreshDatabase;

    public function test_doctor_can_prescribe_lab_requests_and_patient_can_upload_results(): void
    {
        Storage::fake('public');

        // 1. Créer un hôpital vérifié
        $hospital = Hospital::create([
            'name' => 'Centre Hospitalier Universitaire Sylvanus Olympio',
            'city' => 'Lomé',
            'address' => 'Boulevard du 13 Janvier, Lomé',
            'phone' => '+228 90 00 00 00',
            'status' => 'verifie',
        ]);

        // 2. Créer un médecin et un patient
        $doctor = User::factory()->create([
            'role' => 'doctor',
            'hospital_id' => $hospital->id,
            'name' => 'Dr. Paul Mensah',
        ]);

        $patient = User::factory()->create([
            'role' => 'patient',
            'name' => 'Koffi Amegan',
        ]);

        // 3. Créer une consultation en cours
        $consultation = Consultation::create([
            'patient_id' => $patient->id,
            'doctor_id' => $doctor->id,
            'status' => 'en_cours',
            'started_at' => now(),
        ]);

        // 4. Le médecin prescrit des bilans de laboratoire
        $this->actingAs($doctor, 'sanctum');

        $response = $this->postJson("/api/consultations/{$consultation->id}/lab-requests", [
            'clinical_notes' => 'Fièvre continue depuis 3 jours, frissons nocturnes.',
            'urgency_level' => 'urgent',
            'fasting_required' => true,
            'items' => [
                [
                    'name' => 'Goutte Épaisse & Frottis Sanguin (GE/FS)',
                    'category' => 'parasitologie',
                    'instructions' => 'Prélèvement immédiat',
                ],
                [
                    'name' => 'Numération Formule Sanguine (NFS)',
                    'category' => 'biologie',
                    'instructions' => 'Tube EDTA',
                ],
                [
                    'name' => 'Glycémie à jeun',
                    'category' => 'biologie',
                    'instructions' => 'À jeun strict',
                ],
            ],
        ]);

        $response->assertStatus(201);
        $data = $response->json();
        $this->assertStringStartsWith('LAB-', $data['reference_code']);
        $this->assertEquals('urgent', $data['urgency_level']);
        $this->assertTrue($data['fasting_required']);
        $this->assertCount(3, $data['items']);

        $labRequestId = $data['id'];

        // 5. Le patient consulte ses bilans
        $this->actingAs($patient, 'sanctum');

        $myLabsResp = $this->getJson('/api/lab-requests/my');
        $myLabsResp->assertStatus(200);
        $this->assertCount(1, $myLabsResp->json());
        $this->assertEquals($data['reference_code'], $myLabsResp->json()[0]['reference_code']);

        // 6. Le patient téléverse une photo/scan de résultats
        $fakeFile = UploadedFile::fake()->image('resultats_ge_nfs.jpg', 800, 600);

        $uploadResp = $this->postJson("/api/lab-requests/{$labRequestId}/results", [
            'patient_notes' => 'Résultats reçus de l’Institut National d’Hygiène',
            'file' => $fakeFile,
        ]);

        $uploadResp->assertStatus(201);
        $this->assertEquals('resultats_recus', $uploadResp->json()['lab_request']['status']);
        $this->assertCount(1, $uploadResp->json()['lab_request']['results']);

        // 7. Le praticien examine et valide les conclusions
        $this->actingAs($doctor, 'sanctum');

        $reviewResp = $this->postJson("/api/lab-requests/{$labRequestId}/review", [
            'doctor_review_notes' => 'GE positive à Plasmodium falciparum. Début immédiat du traitement ACT (Artéméther + Luméfantrine).',
            'status' => 'analyse_terminee',
        ]);

        $reviewResp->assertStatus(200);
        $this->assertEquals('analyse_terminee', $reviewResp->json()['lab_request']['status']);
        $this->assertNotNull($reviewResp->json()['lab_request']['doctor_review_notes']);

        // 8. Vérifier dans le dossier médical complet du patient
        $dossierResp = $this->getJson("/api/patients/{$patient->id}/dossier");
        $dossierResp->assertStatus(200);
        $this->assertArrayHasKey('lab_requests', $dossierResp->json());
        $this->assertCount(1, $dossierResp->json()['lab_requests']);
    }
}
