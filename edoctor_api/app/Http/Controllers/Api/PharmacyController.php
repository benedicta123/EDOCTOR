<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Medication;
use App\Models\Pharmacy;
use App\Models\PharmacyStock;
use App\Models\Prescription;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class PharmacyController extends Controller
{
    /**
     * GET /api/pharmacies
     * Liste des officines agréées (status = verifie) pour les patients.
     * Si prescription_id est fourni, vérifie la disponibilité de chaque médicament
     * et ne propose que les officines ayant tous les produits en stock.
     */
    public function index(Request $request)
    {
        $prescriptionId = $request->input('prescription_id');
        $prescriptionItems = null;

        if ($prescriptionId) {
            $prescription = Prescription::with('items')->find($prescriptionId);
            if ($prescription) {
                $prescriptionItems = $prescription->items;
            }
        }

        $pharmacies = Pharmacy::where('status', 'verifie')
            ->select(['id', 'name', 'address', 'phone', 'latitude', 'longitude', 'opening_hours', 'reference_id', 'status'])
            ->get();

        if ($prescriptionItems && $prescriptionItems->isNotEmpty()) {
            $pharmacies = $pharmacies->map(function ($pharmacy) use ($prescriptionItems) {
                $allInStock = true;
                $missingItems = [];
                $totalItemsPrice = 0.0;

                foreach ($prescriptionItems as $item) {
                    $stock = PharmacyStock::where('pharmacy_id', $pharmacy->id)
                        ->where('medication_id', $item->medication_id)
                        ->first();

                    if (!$stock || $stock->quantity < $item->quantity || (float) $stock->price <= 0) {
                        $allInStock = false;
                        $med = Medication::find($item->medication_id);
                        $missingItems[] = $med ? $med->name : "Médicament #{$item->medication_id}";
                    } else {
                        $totalItemsPrice += (float) $stock->price * $item->quantity;
                    }
                }

                $pharmacy->in_stock = $allInStock;
                $pharmacy->missing_items = $missingItems;
                $pharmacy->total_items_price = $totalItemsPrice;
                return $pharmacy;
            });

            // Ne proposer que les pharmacies ayant l'intégralité de l'ordonnance en stock
            if ($request->boolean('in_stock_only', true)) {
                $pharmacies = $pharmacies->filter(fn ($p) => $p->in_stock)->values();
            }
        }

        return response()->json($pharmacies);
    }

    /**
     * GET /api/my-pharmacy
     * Récupère l'officine appartenant au pharmacien connecté avec ses stocks.
     */
    public function mine(Request $request)
    {
        abort_if(! $request->user()->isPharmacist(), 403, "Accès réservé aux pharmaciens.");

        $pharmacy = Pharmacy::where('owner_id', $request->user()->id)
            ->with(['stocks.medication'])
            ->firstOrFail();

        return response()->json($pharmacy);
    }

    /**
     * GET /api/pharmacies/{pharmacy}
     */
    public function show(Pharmacy $pharmacy)
    {
        return response()->json($pharmacy->load('stocks.medication'));
    }

    /**
     * PUT /api/pharmacies/{pharmacy}
     */
    public function update(Request $request, Pharmacy $pharmacy)
    {
        Gate::authorize('update', $pharmacy);

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'address' => ['sometimes', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'latitude' => ['sometimes', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'numeric', 'between:-180,180'],
            'opening_hours' => ['nullable', 'array'],
        ]);

        $pharmacy->update($validated);

        return response()->json($pharmacy);
    }
}
