<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Medication;
use App\Models\Order;
use App\Models\PharmacyStock;
use App\Models\Prescription;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        $query = Order::with(['items.medication', 'pharmacy:id,name', 'payment']);

        if ($user->isPharmacist()) {
            $query->whereHas('pharmacy', fn ($q) => $q->where('owner_id', $user->id));
        } else {
            $query->where('patient_id', $user->id);
        }

        return response()->json($query->latest()->get());
    }

    public function show(Request $request, Order $order)
    {
        Gate::authorize('view', $order);

        return response()->json(
            $order->load(['items.medication', 'pharmacy', 'prescription.items.medication', 'payment'])
        );
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'pharmacy_id' => ['required', 'exists:pharmacies,id'],
            'prescription_id' => ['nullable', 'exists:prescriptions,id'],
            'payment_method' => ['required', 'in:mobile_money,carte'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.medication_id' => ['required', 'exists:medications,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
        ]);

        // Vérification de la conformité prescription pour les médicaments soumis à ordonnance
        $medicationIds = collect($validated['items'])->pluck('medication_id')->unique();
        $medications = Medication::whereIn('id', $medicationIds)->get()->keyBy('id');

        $prescriptionRequired = $medications->contains(fn ($med) => $med->requires_prescription);

        if ($prescriptionRequired) {
            if (empty($validated['prescription_id'])) {
                throw ValidationException::withMessages([
                    'prescription_id' => ["Une ordonnance valide est obligatoire pour commander un ou plusieurs médicaments du panier."],
                ]);
            }

            $prescription = Prescription::with('items')
                ->where('id', $validated['prescription_id'])
                ->where('patient_id', $request->user()->id)
                ->where('status', 'validee')
                ->first();

            if (! $prescription) {
                throw ValidationException::withMessages([
                    'prescription_id' => ["L'ordonnance fournie est invalide, non validée ou n'appartient pas au patient."],
                ]);
            }

            $prescriptionItems = $prescription->items->keyBy('medication_id');

            foreach ($validated['items'] as $item) {
                $med = $medications->get($item['medication_id']);
                if ($med && $med->requires_prescription) {
                    if (! $prescriptionItems->has($item['medication_id'])) {
                        throw ValidationException::withMessages([
                            'items' => ["Le médicament '{$med->name}' requiert une ordonnance et ne figure pas sur l'ordonnance fournie."],
                        ]);
                    }

                    $prescribedQuantity = $prescriptionItems->get($item['medication_id'])->quantity;
                    if ($item['quantity'] > $prescribedQuantity) {
                        throw ValidationException::withMessages([
                            'items' => ["La quantité commandée ({$item['quantity']}) pour '{$med->name}' excède la quantité prescrite ({$prescribedQuantity})."],
                        ]);
                    }
                }
            }
        }

        $order = DB::transaction(function () use ($validated, $request) {
            $totalAmount = 0;
            $lockedStocks = [];

            foreach ($validated['items'] as $item) {
                $stock = PharmacyStock::where('pharmacy_id', $validated['pharmacy_id'])
                    ->where('medication_id', $item['medication_id'])
                    ->lockForUpdate()
                    ->first();

                if (! $stock || $stock->quantity < $item['quantity']) {
                    throw ValidationException::withMessages([
                        'items' => ["Stock insuffisant pour le médicament #{$item['medication_id']}."],
                    ]);
                }

                $lockedStocks[] = ['stock' => $stock, 'quantity' => $item['quantity'], 'unit_price' => $stock->price];
                $totalAmount += $stock->price * $item['quantity'];
            }

            $order = Order::create([
                'patient_id' => $request->user()->id,
                'pharmacy_id' => $validated['pharmacy_id'],
                'prescription_id' => $validated['prescription_id'] ?? null,
                'status' => 'confirmee',
                'total_amount' => $totalAmount,
            ]);

            foreach ($lockedStocks as $entry) {
                $entry['stock']->decrement('quantity', $entry['quantity']);

                $order->items()->create([
                    'medication_id' => $entry['stock']->medication_id,
                    'quantity' => $entry['quantity'],
                    'unit_price' => $entry['unit_price'],
                ]);
            }

            $order->payment()->create([
                'method' => $validated['payment_method'],
                'amount' => $totalAmount,
                'status' => 'en_attente',
            ]);

            return $order;
        });

        $order->load(['pharmacy.owner', 'items.medication', 'payment']);

        if ($order->pharmacy && $order->pharmacy->owner) {
            NotificationService::send(
                $order->pharmacy->owner,
                'order_received',
                "Nouvelle commande #{$order->id} reçue d'un montant de {$order->total_amount} FCFA."
            );
        }

        return response()->json($order, 201);
    }

    public function markReady(Request $request, Order $order)
    {
        Gate::authorize('managePharmacySide', $order);

        $order->update(['status' => 'prete']);

        $order->load('patient');
        if ($order->patient) {
            NotificationService::send(
                $order->patient,
                'order_ready',
                "Votre commande #{$order->id} est prête à être récupérée ou expédiée."
            );
        }

        return response()->json($order);
    }

    public function markCollected(Request $request, Order $order)
    {
        Gate::authorize('managePharmacySide', $order);

        $order->update(['status' => 'collectee']);

        $order->load('patient');
        if ($order->patient) {
            NotificationService::send(
                $order->patient,
                'order_collected',
                "Votre commande #{$order->id} a été retirée."
            );
        }

        return response()->json($order);
    }

    public function cancel(Request $request, Order $order)
    {
        Gate::authorize('cancel', $order);

        DB::transaction(function () use ($order) {
            foreach ($order->items as $item) {
                PharmacyStock::where('pharmacy_id', $order->pharmacy_id)
                    ->where('medication_id', $item->medication_id)
                    ->increment('quantity', $item->quantity);
            }

            $order->update(['status' => 'annulee']);
        });

        $order->load(['patient', 'pharmacy.owner']);

        if ($order->patient) {
            NotificationService::send(
                $order->patient,
                'order_cancelled',
                "Votre commande #{$order->id} a été annulée."
            );
        }

        if ($request->user()->id === $order->patient_id && $order->pharmacy && $order->pharmacy->owner) {
            NotificationService::send(
                $order->pharmacy->owner,
                'order_cancelled',
                "La commande #{$order->id} a été annulée par le client."
            );
        }

        return response()->json($order);
    }
}
