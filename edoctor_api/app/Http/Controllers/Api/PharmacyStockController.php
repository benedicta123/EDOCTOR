<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Pharmacy;
use App\Models\PharmacyStock;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class PharmacyStockController extends Controller
{
    /**
     * GET /api/pharmacies/{pharmacy}/stocks
     */
    public function index(Pharmacy $pharmacy)
    {
        return response()->json(
            $pharmacy->stocks()->with('medication')->get()
        );
    }

    /**
     * POST /api/pharmacies/{pharmacy}/stocks
     * Ajoute ou met à jour le stock d'un médicament donné.
     */
    public function storeOrUpdate(Request $request, Pharmacy $pharmacy)
    {
        Gate::authorize('manageStocks', $pharmacy);

        $validated = $request->validate([
            'medication_id' => ['required', 'exists:medications,id'],
            'quantity' => ['required', 'integer', 'min:0'],
            'price' => ['required', 'numeric', 'min:0'],
        ]);

        $stock = PharmacyStock::updateOrCreate(
            [
                'pharmacy_id' => $pharmacy->id,
                'medication_id' => $validated['medication_id'],
            ],
            [
                'quantity' => $validated['quantity'],
                'price' => $validated['price'],
            ]
        );

        return response()->json($stock->load('medication'), 200);
    }

    /**
     * DELETE /api/pharmacies/{pharmacy}/stocks/{stock}
     */
    public function destroy(Pharmacy $pharmacy, PharmacyStock $stock)
    {
        Gate::authorize('manageStocks', $pharmacy);

        abort_if($stock->pharmacy_id !== $pharmacy->id, 404);

        $stock->delete();

        return response()->json(['message' => 'Médicament retiré du stock.']);
    }
}
