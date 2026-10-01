<?php

namespace Database\Seeders;

use App\Models\Claim;
use App\Models\Hospital;
use App\Models\Pharmacy;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class SuperAdminSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Super-Admin National (Régulation & Conformité MSHP)
        $superAdmin = User::updateOrCreate(
            ['email' => 'superadmin@edoctor.test'],
            [
                'name' => 'Inspecteur Général Régulation eDoctor',
                'password' => Hash::make('Password123!'),
                'role' => 'admin',
                'hospital_id' => null, // null = Super-Admin National
                'phone' => '+225 07 10 20 30 40',
            ]
        );

        // 2. Hôpital en attente d'homologation MSHP
        $pendingHospitalAdmin = User::updateOrCreate(
            ['email' => 'directeur.ste-anne@edoctor.test'],
            [
                'name' => 'Dr. Vincent Aké',
                'password' => Hash::make('Password123!'),
                'role' => 'admin',
                'phone' => '+225 07 44 55 66 77',
            ]
        );

        $pendingHospital = Hospital::updateOrCreate(
            ['official_email' => 'direction@clinique-ste-anne.ci'],
            [
                'name' => 'Polyclinique Internationale Sainte-Anne',
                'address' => 'Boulevard Valéry Giscard d\'Estaing, Marcory, Abidjan',
                'status' => 'en_attente',
                'license_number' => 'MSHP-HOMOL-2026-089',
                'tax_number' => 'CI-ABJ-2026-B-89712',
                'phone' => '+225 27 21 35 40 00',
                'license_document_path' => 'documents/homologations/arrete_ministeriel_ste_anne.pdf',
            ]
        );
        $pendingHospitalAdmin->update(['hospital_id' => $pendingHospital->id]);

        // 3. Pharmacie en attente d'agrément KYP
        $pendingPharmacist = User::updateOrCreate(
            ['email' => 'pharmacien.lagunes@edoctor.test'],
            [
                'name' => 'Dr. Christiane Bamba',
                'password' => Hash::make('Password123!'),
                'role' => 'pharmacist',
                'phone' => '+225 05 77 88 99 00',
                'license_number' => 'LIC-OFF-2026-0412',
            ]
        );

        Pharmacy::updateOrCreate(
            ['reference_id' => 'KYP-2026-TG8921'],
            [
                'owner_id' => $pendingPharmacist->id,
                'name' => 'Pharmacie des Lagunes & Étoiles',
                'address' => 'Carrefour Duncan, Deux-Plateaux, Abidjan',
                'phone' => '+225 27 22 41 80 90',
                'official_email' => 'contact@pharmacie-lagunes.ci',
                'status' => 'en_attente',
                'license_number' => 'LIC-OFF-2026-0412',
                'order_number' => 'ONP-CI-2026-0845',
                'tax_number' => 'CI-ABJ-2026-C-33410',
                'documents' => [
                    'licence_officine' => 'documents/pharmacies/licence_officine_lagunes.pdf',
                    'diplome_pharmacien' => 'documents/pharmacies/diplome_docteur_bamba.pdf',
                    'inscription_ordre' => 'documents/pharmacies/attestation_ordre_bamba.pdf',
                ],
            ]
        );

        // 4. Réclamations et Litiges
        $patient = User::where('email', 'patient.jean@edoctor.test')->first();
        $patientMarie = User::where('email', 'patiente.marie@edoctor.test')->first();
        $doctor = User::where('email', 'dr.koffi@edoctor.test')->first();

        if ($patient) {
            Claim::updateOrCreate(
                ['reference_id' => 'REC-2026-00101'],
                [
                    'user_id' => $patient->id,
                    'target_type' => 'pharmacy',
                    'category' => 'dispensation',
                    'priority' => 'haute',
                    'subject' => 'Retard de préparation et livraison de médicaments prescrits',
                    'description' => 'Ma commande de médicaments contenant l\'amoxicilline prescrite lors de la téléconsultation n\'a pas été préparée dans le délai promis de 2h.',
                    'status' => 'ouvert',
                ]
            );
        }

        if ($patientMarie) {
            Claim::updateOrCreate(
                ['reference_id' => 'REC-2026-00102'],
                [
                    'user_id' => $patientMarie->id,
                    'target_type' => 'platform',
                    'category' => 'facturation',
                    'priority' => 'urgente',
                    'subject' => 'Double débit Mobile Money (Flooz / T-Money)',
                    'description' => 'Lors du règlement de la téléconsultation pédiatrique, le compte a été débité 2 fois de 7 500 FCFA. Demande de remboursement de l\'un des prélèvements.',
                    'status' => 'ouvert',
                ]
            );
        }

        if ($doctor) {
            Claim::updateOrCreate(
                ['reference_id' => 'REC-2026-00103'],
                [
                    'user_id' => $doctor->id,
                    'target_type' => 'consultation',
                    'category' => 'technique',
                    'priority' => 'normale',
                    'subject' => 'Coupure flux vidéo en pleine téléconsultation cardiologique',
                    'description' => 'Perte de synchronisation audio/vidéo WebRTC sur le patient vers la 15ème minute. Nécessité d\'un contrôle de la bande passante du serveur relais TURN.',
                    'status' => 'en_cours',
                ]
            );
        }
    }
}
