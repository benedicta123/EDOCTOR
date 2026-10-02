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
     */
    public function markDelivered(Request $request, Delivery $delivery)
    {
        abort_if($delivery->order->pharmacy->owner_id !== $request->user()->id, 403);

        $delivery->update(['status' => 'livree']);
        $delivery->order->update(['status' => 'collectee']);

        NotificationService::send(
            $delivery->order->patient,
            'delivery_livree',
            "Votre commande #{$delivery->order_id} a été livrée."
        );

        return response()->json($delivery);
    }
}
