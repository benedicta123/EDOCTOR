<?php

namespace Database\Seeders;

use App\Models\Medication;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Pharmacy;
use App\Models\PharmacyStock;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class TestVerifiedPharmacySeeder extends Seeder
{
    public function run(): void
    {
        // 1. Pharmacien titulaire de test
        $pharmacist = User::updateOrCreate(
            ['email' => 'pharmacien.test@edoctor.tg'],
            [
                'name' => 'Dr. Koffi Mensah',
                'password' => Hash::make('Password123!'),
                'role' => 'pharmacist',
                'phone' => '+228 90 22 33 44',
                'address' => 'Boulevard du 13 Janvier, Lomé, Togo',
            ]
        );

        // 2. Pharmacie Vérifiée & Agréée
        $pharmacy = Pharmacy::where('reference_id', 'KYP-2026-TG777')
            ->orWhere('owner_id', $pharmacist->id)
            ->first();

        if (! $pharmacy) {
            $pharmacy = new Pharmacy();
            $pharmacy->reference_id = 'KYP-2026-TG777';
        }

        $pharmacy->owner_id = $pharmacist->id;
        $pharmacy->name = 'Grande Pharmacie du Golfe';
        $pharmacy->status = 'verifie';
        $pharmacy->license_number = 'MSHP/DPM/2024-042';
        $pharmacy->order_number = 'ONPT-2024-089';
        $pharmacy->official_email = 'contact@pharmacie-golfe.tg';
        $pharmacy->address = 'Boulevard du 13 Janvier, Quartier Déckon, Lomé, Togo';
        $pharmacy->phone = '+228 22 21 00 00';
        $pharmacy->latitude = 6.1360000;
        $pharmacy->longitude = 1.2220000;
        $pharmacy->opening_hours = [
            'lundi-vendredi' => '07:30 - 21:30',
            'samedi' => '08:00 - 20:00',
            'dimanche' => 'Garde assurée 24h/24',
        ];
        $pharmacy->verified_at = now();
        $pharmacy->rejected_reason = null;
        $pharmacy->save();

        // 3. Mise à jour des stocks de médicaments
        $stocksData = [
            1 => ['qty' => 120, 'price' => 1500.00], // Paracétamol 1000mg
            2 => ['qty' => 8,   'price' => 3200.00], // Amoxicilline 500mg (Faible)
            3 => ['qty' => 45,  'price' => 2200.00], // Ibuprofène 400mg
            4 => ['qty' => 3,   'price' => 4800.00], // Azithromycine 250mg (Critique)
            5 => ['qty' => 0,   'price' => 1800.00], // Vitamine C 1000mg (Rupture)
        ];

        foreach ($stocksData as $medId => $data) {
            if (Medication::where('id', $medId)->exists()) {
                PharmacyStock::updateOrCreate(
                    [
                        'pharmacy_id' => $pharmacy->id,
                        'medication_id' => $medId,
                    ],
                    [
                        'quantity' => $data['qty'],
                        'price' => $data['price'],
                    ]
                );
            }
        }

        // 4. Commandes de démonstration pour le tableau de bord et l'écran des commandes
        $patientJean = User::where('email', 'patient.jean@edoctor.test')->first();
        $patientMarie = User::where('email', 'patiente.marie@edoctor.test')->first();
        $patientBenedicta = User::where('email', 'benedictehounkanli@gmail.com')->first();

        // Supprimer d'anciennes commandes de test pour cette pharmacie pour avoir des données nettes
        Order::where('pharmacy_id', $pharmacy->id)->delete();

        if ($patientJean) {
            $order1 = Order::create([
                'patient_id' => $patientJean->id,
                'pharmacy_id' => $pharmacy->id,
                'status' => 'confirmee', // Nouvelle commande en attente de préparation
                'total_amount' => 6200.00,
            ]);

            OrderItem::create([
                'order_id' => $order1->id,
                'medication_id' => 1,
                'quantity' => 2,
                'unit_price' => 1500.00,
            ]);

            OrderItem::create([
                'order_id' => $order1->id,
                'medication_id' => 2,
                'quantity' => 1,
                'unit_price' => 3200.00,
            ]);
        }

        if ($patientMarie) {
            $order2 = Order::create([
                'patient_id' => $patientMarie->id,
                'pharmacy_id' => $pharmacy->id,
                'status' => 'prete', // Prête à emporter
                'total_amount' => 4400.00,
            ]);

            OrderItem::create([
                'order_id' => $order2->id,
                'medication_id' => 3,
                'quantity' => 2,
                'unit_price' => 2200.00,
            ]);
        }

        if ($patientBenedicta) {
            $order3 = Order::create([
                'patient_id' => $patientBenedicta->id,
                'pharmacy_id' => $pharmacy->id,
                'status' => 'collectee', // Déjà livrée/retirée
                'total_amount' => 4800.00,
            ]);

            OrderItem::create([
                'order_id' => $order3->id,
                'medication_id' => 4,
                'quantity' => 1,
                'unit_price' => 4800.00,
            ]);
        }

        // 5. Valider également le compte Pharmacie Avepozo (si déjà créé par l'utilisateur)
        $avepozo = Pharmacy::where('name', 'like', '%AVEPOZO%')->first();
        if ($avepozo) {
            $avepozo->update([
                'status' => 'verifie',
                'verified_at' => now(),
            ]);

            // Ajouter également quelques stocks à cette pharmacie
            foreach ($stocksData as $medId => $data) {
                if (Medication::where('id', $medId)->exists()) {
                    PharmacyStock::updateOrCreate(
                        [
                            'pharmacy_id' => $avepozo->id,
                            'medication_id' => $medId,
                        ],
                        [
                            'quantity' => $data['qty'],
                            'price' => $data['price'],
                        ]
                    );
                }
            }
        }
    }
}
