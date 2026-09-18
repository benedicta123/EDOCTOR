<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Delivery;
use App\Models\Order;
use App\Services\NotificationService;
use Illuminate\Http\Request;

class DeliveryController extends Controller
{
    /**
     * POST /api/orders/{order}/delivery
     * Transforme une commande en livraison à domicile (au lieu d'un retrait en pharmacie).
     * Le patient choisit ce mode juste après la confirmation de sa commande.
     */
    public function store(Request $request, Order $order)
    {
        abort_if($request->user()->id !== $order->patient_id, 403);

        $validated = $request->validate([
            'address' => ['required', 'string', 'max:255'],
        ]);

        $delivery = Delivery::create([
            'order_id' => $order->id,
            'address' => $validated['address'],
            'status' => 'en_attente',
        ]);

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
