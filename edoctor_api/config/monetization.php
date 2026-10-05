<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Modèle Économique & Tarification eDoctor (Directives DG Octobre 2026)
    |--------------------------------------------------------------------------
    |
    | Hôpitaux : 100% du tarif consultation reversé (0% de prélèvement eDoctor).
    | Pharmacies : 100% du prix médicaments reversé (0% de prélèvement eDoctor).
    |
    */

    // Frais plateforme sur chaque téléconsultation (payés par le patient, 10% du tarif hôpital)
    'consultation' => [
        'default_hospital_fee' => (float) env('EDOCTOR_DEFAULT_CONSULTATION_FEE', 3000.0),
        'platform_fee_rate' => (float) env('EDOCTOR_CONSULTATION_PLATFORM_RATE', 0.10), // 10% du tarif de consultation hôpital
        'platform_fee' => (float) env('EDOCTOR_CONSULTATION_PLATFORM_FEE', 600.0), // Ancien forfait fixe conservé comme fallback
    ],

    // Frais plateforme de géolocalisation d'officine avec stock garanti en direct
    'pharmacy' => [
        'finder_fee' => (float) env('EDOCTOR_PHARMACY_FINDER_FEE', 150.0),
    ],

    // Barème kilométrique de livraison à domicile
    'delivery' => [
        'base_fee' => (float) env('EDOCTOR_DELIVERY_BASE_FEE', 500.0), // Forfait pour ≤ 2 km
        'base_distance_km' => (float) env('EDOCTOR_DELIVERY_BASE_DISTANCE_KM', 2.0),
        'per_km_fee' => (float) env('EDOCTOR_DELIVERY_PER_KM_FEE', 150.0), // Au-delà de 2 km
        'courier_share_ratio' => (float) env('EDOCTOR_DELIVERY_COURIER_RATIO', 0.75), // 75% coursier / 25% eDoctor
    ],

    // Prestations de soins infirmiers à domicile
    'nurse_visit' => [
        'default_hospital_fee' => (float) env('EDOCTOR_DEFAULT_NURSE_FEE', 5000.0),
        'platform_fee' => (float) env('EDOCTOR_NURSE_PLATFORM_FEE', 600.0),
    ],
];
