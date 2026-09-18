<?php

namespace Database\Seeders;

use App\Models\Consultation;
use App\Models\Hospital;
use App\Models\Medication;
use App\Models\Pharmacy;
use App\Models\PharmacyStock;
use App\Models\Prescription;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database with a fully-functional medical ecosystem.
     */
    public function run(): void
    {
        // 1. Établissement Hospitalier Certifié
        $hospital = Hospital::updateOrCreate(
            ['official_email' => 'direction@chu-demo.ci'],
            [
                'name' => 'Centre Hospitalier Universitaire de Démo',
                'address' => 'Boulevard Médical, Cocody, Abidjan',
                'latitude' => 5.3484342,
                'longitude' => -4.0141671,
                'status' => 'verifie',
                'license_number' => 'AGR-MSHP-2024-042',
                'tax_number' => 'CI-ABJ-2024-B-12345',
                'phone' => '+225 27 22 00 00 00',
                'verified_at' => now(),
            ]
        );

        // 2. Super-Administrateur de l'Hôpital (Directeur)
        $admin = User::updateOrCreate(
            ['email' => 'admin.chu@edoctor.test'],
            [
                'name' => 'Dr. Kouamé Directeur',
                'password' => Hash::make('Password123!'),
                'role' => 'admin',
                'hospital_id' => $hospital->id,
                'phone' => '+225 07 00 00 01 01',
            ]
        );

        // 3. Médecins rattachés à l'hôpital
        $doctor1 = User::updateOrCreate(
            ['email' => 'dr.koffi@edoctor.test'],
            [
                'name' => 'Dr. Paul Koffi',
                'password' => Hash::make('Password123!'),
                'role' => 'doctor',
                'hospital_id' => $hospital->id,
                'specialty' => 'Médecine Générale',
                'license_number' => 'ONM-CI-2018-456',
                'phone' => '+225 07 00 00 02 01',
                'last_seen_at' => now(), // Considéré en ligne
                'availability_status' => null, // Disponible
            ]
        );

        $doctor2 = User::updateOrCreate(
            ['email' => 'dr.amina@edoctor.test'],
            [
                'name' => 'Dr. Amina Touré',
                'password' => Hash::make('Password123!'),
                'role' => 'doctor',
                'hospital_id' => $hospital->id,
                'specialty' => 'Pédiatrie',
                'license_number' => 'ONM-CI-2020-789',
                'phone' => '+225 07 00 00 02 02',
                'last_seen_at' => now(), // Considéré en ligne
                'availability_status' => null, // Disponible
            ]
        );

        // 4. Infirmiers rattachés à l'hôpital
        $nurse1 = User::updateOrCreate(
            ['email' => 'infirmier.paul@edoctor.test'],
            [
                'name' => 'Infirmier Paul Yao',
                'password' => Hash::make('Password123!'),
                'role' => 'nurse',
                'hospital_id' => $hospital->id,
                'availability_status' => 'disponible',
                'license_number' => 'INF-2021-334',
                'phone' => '+225 05 00 00 03 01',
                'last_seen_at' => now(),
            ]
        );

        $nurse2 = User::updateOrCreate(
            ['email' => 'infirmiere.sarah@edoctor.test'],
            [
                'name' => 'Infirmière Sarah Koné',
                'password' => Hash::make('Password123!'),
                'role' => 'nurse',
                'hospital_id' => $hospital->id,
                'availability_status' => 'disponible',
                'license_number' => 'INF-2022-556',
                'phone' => '+225 05 00 00 03 02',
                'last_seen_at' => now(),
            ]
        );

        // 5. Patients
        $patient1 = User::updateOrCreate(
            ['email' => 'patient.jean@edoctor.test'],
            [
                'name' => 'Jean Dupont',
                'password' => Hash::make('Password123!'),
                'role' => 'patient',
                'phone' => '+225 01 00 00 04 01',
                'date_of_birth' => '1990-05-15',
                'address' => 'Cocody Angré 8ème Tranche, Abidjan',
                'medical_history_summary' => 'Allergie connue à la pénicilline, asthme modéré depuis l\'enfance.',
            ]
        );

        $patient2 = User::updateOrCreate(
            ['email' => 'patiente.marie@edoctor.test'],
            [
                'name' => 'Marie Kouassi',
                'password' => Hash::make('Password123!'),
                'role' => 'patient',
                'phone' => '+225 01 00 00 04 02',
                'date_of_birth' => '1995-11-20',
                'address' => 'Marcory Zone 4, Abidjan',
                'medical_history_summary' => 'Hypertension artérielle légère sous surveillance.',
            ]
        );

        // 6. Pharmaciens & Pharmacies Partenaires (3 Pharmacies)
        $pharmacist1 = User::updateOrCreate(
            ['email' => 'pharmacien.luc@edoctor.test'],
            [
                'name' => 'Dr. Luc Bernard',
                'password' => Hash::make('Password123!'),
                'role' => 'pharmacist',
                'license_number' => 'ONP-CI-2015-112',
                'phone' => '+225 07 00 00 05 01',
            ]
        );

        $pharmacy1 = Pharmacy::updateOrCreate(
            ['owner_id' => $pharmacist1->id],
            [
                'name' => 'Grande Pharmacie Centrale de Démo',
                'address' => 'Avenue Chardy, Plateau, Abidjan',
                'latitude' => 5.3260931,
                'longitude' => -4.0196723,
                'phone' => '+225 27 20 00 00 00',
                'opening_hours' => [
                    'lundi-vendredi' => '08:00 - 21:00',
                    'samedi' => '08:00 - 18:00',
                    'dimanche' => 'Garde 24h/24',
                ],
            ]
        );

        $pharmacist2 = User::updateOrCreate(
            ['email' => 'pharmacienne.fatou@edoctor.test'],
            [
                'name' => 'Dr. Fatou Diallo',
                'password' => Hash::make('Password123!'),
                'role' => 'pharmacist',
                'license_number' => 'ONP-CI-2017-234',
                'phone' => '+225 07 00 00 05 02',
            ]
        );

        $pharmacy2 = Pharmacy::updateOrCreate(
            ['owner_id' => $pharmacist2->id],
            [
                'name' => 'Pharmacie de la Paix & Espérance',
                'address' => 'Boulevard de Marseille, Zone 4, Abidjan',
                'latitude' => 5.2954120,
                'longitude' => -3.9887120,
                'phone' => '+225 27 21 00 00 01',
                'opening_hours' => [
                    'lundi-samedi' => '07:30 - 22:00',
                    'dimanche' => '09:00 - 19:00',
                ],
            ]
        );

        $pharmacist3 = User::updateOrCreate(
            ['email' => 'pharmacien.marc@edoctor.test'],
            [
                'name' => 'Dr. Marc Yao',
                'password' => Hash::make('Password123!'),
                'role' => 'pharmacist',
                'license_number' => 'ONP-CI-2019-567',
                'phone' => '+225 07 00 00 05 03',
            ]
        );

        $pharmacy3 = Pharmacy::updateOrCreate(
            ['owner_id' => $pharmacist3->id],
            [
                'name' => 'Pharmacie Sainte-Marie',
                'address' => 'Boulevard Latrille, Cocody Angré, Abidjan',
                'latitude' => 5.3789120,
                'longitude' => -3.9923410,
                'phone' => '+225 27 22 00 00 02',
                'opening_hours' => [
                    'lundi-dimanche' => '24h/24 - 7j/7 (Permanence)',
                ],
            ]
        );

        // 7. Catalogue des Médicaments
        $medications = [
            [
                'name' => 'Paracétamol 1000mg',
                'dosage' => '1000 mg',
                'form' => 'Comprimé',
                'category' => 'Antalgique / Antipyrétique',
                'requires_prescription' => false,
                'price' => 1500.00,
                'quantity' => 120,
            ],
            [
                'name' => 'Amoxicilline 500mg',
                'dosage' => '500 mg',
                'form' => 'Gélule',
                'category' => 'Antibiotique',
                'requires_prescription' => true,
                'price' => 3200.00,
                'quantity' => 60,
            ],
            [
                'name' => 'Ibuprofène 400mg',
                'dosage' => '400 mg',
                'form' => 'Comprimé',
                'category' => 'Anti-inflammatoire',
                'requires_prescription' => false,
                'price' => 2000.00,
                'quantity' => 85,
            ],
            [
                'name' => 'Azithromycine 250mg',
                'dosage' => '250 mg',
                'form' => 'Comprimé pelliculé',
                'category' => 'Antibiotique',
                'requires_prescription' => true,
                'price' => 5500.00,
                'quantity' => 40,
            ],
            [
                'name' => 'Vitamine C 1000mg',
                'dosage' => '1000 mg',
                'form' => 'Comprimé effervescent',
                'category' => 'Complément Vitaminique',
                'requires_prescription' => false,
                'price' => 1800.00,
                'quantity' => 150,
            ],
        ];

        foreach ($medications as $medData) {
            $price = $medData['price'];
            $quantity = $medData['quantity'];
            unset($medData['price'], $medData['quantity']);

            $medication = Medication::updateOrCreate(
                ['name' => $medData['name']],
                $medData
            );

            foreach ([$pharmacy1, $pharmacy2, $pharmacy3] as $index => $pharm) {
                PharmacyStock::updateOrCreate(
                    [
                        'pharmacy_id' => $pharm->id,
                        'medication_id' => $medication->id,
                    ],
                    [
                        'quantity' => $quantity + ($index * 10),
                        'price' => $price + ($index * 50),
                    ]
                );
            }
        }

        // 8. Consultation d'exemple avec ordonnance (pour tester le dossier médical & commande immédiate)
        $consultation = Consultation::firstOrCreate(
            [
                'patient_id' => $patient1->id,
                'doctor_id' => $doctor1->id,
                'status' => 'terminee',
            ],
            [
                'scheduled_at' => now()->subDays(2),
                'started_at' => now()->subDays(2),
                'ended_at' => now()->subDays(2)->addMinutes(25),
            ]
        );

        $amoxicilline = Medication::where('name', 'Amoxicilline 500mg')->first();

        $prescription = Prescription::firstOrCreate(
            ['consultation_id' => $consultation->id],
            [
                'doctor_id' => $doctor1->id,
                'patient_id' => $patient1->id,
                'status' => 'validee',
                'home_care_recommended' => true,
            ]
        );

        if ($amoxicilline && $prescription->items()->count() === 0) {
            $prescription->items()->create([
                'medication_id' => $amoxicilline->id,
                'dosage_instructions' => '1 gélule matin et soir pendant 6 jours avec un verre d\'eau',
                'quantity' => 2,
            ]);
        }
    }
}
