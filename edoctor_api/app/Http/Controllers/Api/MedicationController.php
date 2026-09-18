<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Medication;
use Illuminate\Http\Request;

class MedicationController extends Controller
{
    /**
     * GET /api/medications
     * Recherche et liste des médicaments disponibles dans le catalogue général.
     */
    public function index(Request $request)
    {
        $query = Medication::query();

        if ($request->filled('q')) {
            $search = strtolower($request->string('q'));
            $query->whereRaw('LOWER(name) LIKE ?', ["%{$search}%"]);
        }

        if ($request->filled('category')) {
            $query->where('category', $request->string('category'));
        }

        if ($request->has('requires_prescription')) {
            $query->where('requires_prescription', $request->boolean('requires_prescription'));
        }

        $medications = $query->orderBy('name')->paginate($request->integer('per_page', 20));

        return response()->json($medications);
    }

    /**
     * GET /api/medications/{medication}
     */
    public function show(Medication $medication)
    {
        return response()->json($medication);
    }
}
