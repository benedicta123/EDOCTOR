<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Models\Order;
use App\Services\MonetizationService;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DeliveryController extends Controller
{
    /**
     * POST /api/deliveries/quote
     * Devis de livraison selon le barème kilométrique DG v2.0 (500 F 2km + 150 F/km).
     */
    public function quote(Request $request)
    {
        $validated = $request->validate([
            'distance_km' => ['nullable', 'numeric', 'min:0'],
            'pharmacy_latitude' => ['nullable', 'numeric'],
            'pharmacy_longitude' => ['nullable', 'numeric'],
            'patient_latitude' => ['nullable', 'numeric'],
            'patient_longitude' => ['nullable', 'numeric'],
        ]);

        $distanceKm = (float) ($validated['distance_km'] ?? 0.0);
        if ($distanceKm <= 0 && !empty($validated['pharmacy_latitude']) && !empty($validated['pharmacy_longitude']) && !empty($validated['patient_latitude']) && !empty($validated['patient_longitude'])) {
            $distanceKm = MonetizationService::calculateDistance(
                (float) $validated['pharmacy_latitude'],
                (float) $validated['pharmacy_longitude'],
                (float) $validated['patient_latitude'],
                (float) $validated['patient_longitude']
            );
        }

        return response()->json(MonetizationService::calculateDeliveryPricing($distanceKm));
    }

    /**
     * POST /api/orders/{order}/delivery
     * Transforme une commande en livraison à domicile (au lieu d'un retrait en pharmacie).
     */
    public function store(Request $request, Order $order)
    {
        abort_if($request->user()->id !== $order->patient_id, 403);

        $validated = $request->validate([
            'address' => ['required', 'string', 'max:255'],
            'distance_km' => ['nullable', 'numeric', 'min:0'],
            'patient_latitude' => ['nullable', 'numeric'],
            'patient_longitude' => ['nullable', 'numeric'],
        ]);

        $distanceKm = (float) ($validated['distance_km'] ?? 0.0);
        $pharmacy = $order->pharmacy;

        if ($distanceKm <= 0 && !empty($validated['patient_latitude']) && !empty($validated['patient_longitude']) && !empty($pharmacy->latitude) && !empty($pharmacy->longitude)) {
            $distanceKm = MonetizationService::calculateDistance(
                (float) $pharmacy->latitude,
                (float) $pharmacy->longitude,
                (float) $validated['patient_latitude'],
                (float) $validated['patient_longitude']
            );
        }

        $deliveryPricing = MonetizationService::calculateDeliveryPricing($distanceKm);

        $delivery = DB::transaction(function () use ($order, $validated, $deliveryPricing) {
            $delivery = Delivery::create([
                'order_id' => $order->id,
                'address' => $validated['address'],
                'distance_km' => $deliveryPricing['distance_km'],
                'delivery_fee' => $deliveryPricing['delivery_fee'],
                'courier_share' => $deliveryPricing['courier_share'],
                'edoctor_share' => $deliveryPricing['edoctor_share'],
                'status' => 'en_attente',
            ]);

            // Mettre à jour les totaux de la commande
            $order->update([
                'delivery_fee' => $deliveryPricing['delivery_fee'],
                'delivery_distance_km' => $deliveryPricing['distance_km'],
                'total_amount' => $order->total_amount + $deliveryPricing['delivery_fee'],
            ]);

            // Mettre à jour le paiement si existant
            if ($order->payment) {
                $order->payment->update([
                    'amount' => $order->total_amount,
                    'courier_share' => $deliveryPricing['courier_share'],
                    'edoctor_fee' => $order->payment->edoctor_fee + $deliveryPricing['edoctor_share'],
                ]);
            }

            return $delivery;
        });

        return response()->json($delivery, 201);
    }

    /**
     * POST /api/deliveries/{delivery}/assign
     * Assignation manuelle en V1 — le pharmacien indique qui livre.
     */
    public function assign(Request $request, Delivery $delivery)
    {
        abort_if($delivery->order->pharmacy->owner_id !== $request->user()->id, 403);

        $validated = $request->validate([
            'courier_name' => ['required', 'string', 'max:255'],
        ]);

        $delivery->update([
            'courier_name' => $validated['courier_name'],
            'status' => 'en_route',
        ]);

        NotificationService::send(
            $delivery->order->patient,
            'delivery_en_route',
            "Votre commande #{$delivery->order_id} est en route avec {$validated['courier_name']}."
        );

        return response()->json($delivery);
    }

    /**
     * POST /api/deliveries/{delivery}/mark-delivered
     * Valide la livraison à domicile et crédite immédiatement le portefeuille de la pharmacie.
     * Accessible :
     *  - Au pharmacien (avec saisie obligatoire du code secret remis par le patient au livreur)
     *  - Au patient lui-même (confirmation directe "J'ai bien reçu mon colis" sur son application)
     *  - À l'administrateur
     */
    public function markDelivered(Request $request, Delivery $delivery)
    {
        $user = $request->user();
        $order = $delivery->order;
        $pharmacy = $order->pharmacy;

        $isPharmacyOwner = $pharmacy && $pharmacy->owner_id === $user->id;
        $isPatient = $order->patient_id === $user->id;
        $isAdmin = $user->isAdmin();

        abort_unless($isPharmacyOwner || $isPatient || $isAdmin, 403, "Accès non autorisé pour valider cette livraison.");

        if ($delivery->status === 'livree' || $order->status === 'collectee') {
            return response()->json(['message' => 'Cette livraison a déjà été marquée comme effectuée.'], 422);
        }

        // Si c'est la pharmacie ou un tiers qui valide, le code secret à 4 chiffres du patient est OBLIGATOIRE
        if (!$isPatient && !$isAdmin) {
            $validated = $request->validate([
                'pickup_code' => ['required', 'string'],
            ]);

            if (!empty($order->pickup_code) && trim((string) $validated['pickup_code']) !== trim((string) $order->pickup_code)) {
                return response()->json([
                    'message' => 'Code secret de livraison invalide. Veuillez demander au patient son code à 4 chiffres ou scanner son QR code.',
                ], 422);
            }
        }

        DB::transaction(function () use ($delivery, $order, $pharmacy) {
            $delivery->update(['status' => 'livree']);
            $order->update([
                'status' => 'collectee',
                'collected_at' => now(),
            ]);

            // 1. Crédit automatique du portefeuille de la pharmacie pour les médicaments vendus
            if ($pharmacy) {
                $wallet = $pharmacy->getOrCreateWallet();
                $itemsAmount = (float) $order->items_amount;
                if ($itemsAmount > 0) {
                    $wallet->credit(
                        $itemsAmount,
                        "Encaissement vente de médicaments livrés à domicile — Commande #{$order->id}",
                        'order',
                        $order->id
                    );
                }
            }

            // 2. Marquer le paiement comme confirmé si applicable
            if ($order->payment && $order->payment->status !== 'confirme') {
                $order->payment->update(['status' => 'confirme']);
            }
        });

        $order->load(['pharmacy.owner', 'patient']);

        // Notifications automatiques
        if ($order->patient) {
            NotificationService::send(
                $order->patient,
                'delivery_livree',
                "Votre commande #{$order->id} a été livrée avec succès à votre domicile."
            );
        }

        if ($order->pharmacy && $order->pharmacy->owner) {
            NotificationService::send(
                $order->pharmacy->owner,
                'order_collected',
                "La livraison à domicile de la commande #{$order->id} est confirmée. Le montant des médicaments a été versé sur votre solde disponible."
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Livraison confirmée avec succès. Portefeuille de la pharmacie crédité.',
            'delivery' => $delivery->fresh(['order']),
        ]);
    }
}
