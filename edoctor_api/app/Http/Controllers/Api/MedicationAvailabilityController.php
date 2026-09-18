<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Medication;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MedicationAvailabilityController extends Controller
{
    /**
     * Liste les pharmacies proches ayant ce médicament en stock,
     * triées par distance (formule de Haversine).
     *
     * GET /api/medications/{medication}/availability?lat=..&lng=..&radius_km=10
     */
    public function nearby(Request $request, Medication $medication)
    {
        $validated = $request->validate([
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
            'radius_km' => ['nullable', 'numeric', 'min:0.5', 'max:50'],
        ]);

        $lat = $validated['lat'];
        $lng = $validated['lng'];
        $radiusKm = $validated['radius_km'] ?? 10;

        // Haversine directement en SQL : suffisant pour un MVP, pas besoin de PostGIS ici.
        $distanceExpr = "
            6371 * acos(
                cos(radians(?)) * cos(radians(pharmacies.latitude)) *
                cos(radians(pharmacies.longitude) - radians(?)) +
                sin(radians(?)) * sin(radians(pharmacies.latitude))
            )
        ";

        $results = DB::table('pharmacy_stocks')
            ->join('pharmacies', 'pharmacies.id', '=', 'pharmacy_stocks.pharmacy_id')
            ->where('pharmacy_stocks.medication_id', $medication->id)
            ->where('pharmacy_stocks.quantity', '>', 0)
            ->selectRaw(
                "pharmacies.id, pharmacies.name, pharmacies.address, pharmacies.latitude, pharmacies.longitude, ".
                "pharmacy_stocks.quantity, pharmacy_stocks.price, ($distanceExpr) as distance_km",
                [$lat, $lng, $lat]
            )
            ->havingRaw("($distanceExpr) <= ?", [$lat, $lng, $lat, $radiusKm])
            ->orderBy('distance_km')
            ->get();

        return response()->json([
            'medication' => $medication->only(['id', 'name', 'dosage', 'requires_prescription']),
            'pharmacies' => $results,
        ]);
    }
}
