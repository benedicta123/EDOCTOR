<?php

namespace App\Services;

use App\Models\Hospital;
use App\Models\User;

class MonetizationService
{
    /**
     * Calcule le découpage financier d'une téléconsultation médicale.
     * Règle DG : 100% du tarif revient à l'hôpital/médecin, + 600 FCFA fixe eDoctor.
     */
    public static function calculateConsultationPricing(?Hospital $hospital = null, ?User $doctor = null): array
    {
        $hospitalFee = (float) config('monetization.consultation.default_hospital_fee', 3000.0);

        if ($doctor && isset($doctor->consultation_fee) && $doctor->consultation_fee > 0) {
            $hospitalFee = (float) $doctor->consultation_fee;
        } elseif ($hospital && isset($hospital->consultation_fee) && $hospital->consultation_fee > 0) {
            $hospitalFee = (float) $hospital->consultation_fee;
        }

        $platformFee = (float) config('monetization.consultation.platform_fee', 600.0);
        $totalAmount = $hospitalFee + $platformFee;

        return [
            'consultation_fee' => $hospitalFee,
            'hospital_share' => $hospitalFee, // 100% reversé à la structure médicale
            'edoctor_fee' => $platformFee,     // 600 FCFA net (absorbe frais Mobile Money)
            'total_amount' => $totalAmount,
        ];
    }

    /**
     * Calcule les frais de livraison d'ordonnance selon le barème kilométrique officiel.
     * Règle DG : 500 FCFA pour ≤ 2 km + 150 FCFA par km supplémentaire.
     * Répartition : ~75% pour le coursier, ~25% pour la marge eDoctor.
     */
    public static function calculateDeliveryPricing(float $distanceKm): array
    {
        $distanceKm = max(0.0, round($distanceKm, 2));
        $baseFee = (float) config('monetization.delivery.base_fee', 500.0);
        $baseKm = (float) config('monetization.delivery.base_distance_km', 2.0);
        $perKmFee = (float) config('monetization.delivery.per_km_fee', 150.0);
        $ratio = (float) config('monetization.delivery.courier_share_ratio', 0.75);

        $additionalFee = 0.0;
        if ($distanceKm > $baseKm) {
            $extraKm = ceil($distanceKm - $baseKm);
            $additionalFee = $extraKm * $perKmFee;
        }

        $deliveryFee = $baseFee + $additionalFee;
        $courierShare = (float) round($deliveryFee * $ratio);
        $edoctorShare = (float) ($deliveryFee - $courierShare);

        return [
            'distance_km' => $distanceKm,
            'delivery_fee' => $deliveryFee,
            'courier_share' => $courierShare,
            'edoctor_share' => $edoctorShare,
        ];
    }

    /**
     * Calcule le montant total et le split pour une commande de pharmacie.
     * Règle DG : 100% du prix médicament à la pharmacie, 150 FCFA frais recherche stock eDoctor,
     * et livraison calculée au kilomètre si demandée.
     */
    public static function calculateOrderPricing(float $itemsTotal, bool $withDelivery = false, float $distanceKm = 0.0): array
    {
        $finderFee = (float) config('monetization.pharmacy.finder_fee', 150.0);
        $deliveryPricing = $withDelivery ? self::calculateDeliveryPricing($distanceKm) : null;

        $deliveryFee = $deliveryPricing ? $deliveryPricing['delivery_fee'] : 0.0;
        $courierShare = $deliveryPricing ? $deliveryPricing['courier_share'] : 0.0;
        $edoctorDeliveryShare = $deliveryPricing ? $deliveryPricing['edoctor_share'] : 0.0;

        $totalAmount = $itemsTotal + $finderFee + $deliveryFee;
        $edoctorTotalRevenue = $finderFee + $edoctorDeliveryShare;

        return [
            'items_amount' => $itemsTotal,
            'pharmacy_share' => $itemsTotal, // 100% reversé à l'officine
            'edoctor_fee' => $finderFee,     // 150 FCFA frais de mise en relation & stock direct
            'edoctor_order_fee' => $finderFee,
            'with_delivery' => $withDelivery,
            'delivery_fee' => $deliveryFee,
            'distance_km' => $distanceKm,
            'courier_share' => $courierShare,
            'edoctor_delivery_share' => $edoctorDeliveryShare,
            'edoctor_total_revenue' => $edoctorTotalRevenue,
            'total_amount' => $totalAmount,
        ];
    }

    /**
     * Calcule la distance orthodromique (en kilomètres) entre deux coordonnées GPS (Formule de Haversine).
     */
    public static function calculateDistance(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthRadius = 6371; // Rayon moyen de la Terre en km

        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return round($earthRadius * $c, 2);
    }
}
