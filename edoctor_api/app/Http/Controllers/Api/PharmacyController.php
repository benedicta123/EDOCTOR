<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Pharmacy;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class PharmacyController extends Controller
{
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
