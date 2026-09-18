<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hospital;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class HospitalStaffController extends Controller
{
    /**
     * GET /api/my-hospital/staff
     * Liste du personnel soignant (médecins et infirmiers) rattaché à l'établissement de l'administrateur connecté.
     */
    public function index(Request $request)
    {
        $user = $request->user();
        abort_if(! $user->isAdmin() || ! $user->hospital_id, 403, "Accès réservé aux administrateurs d'hôpital.");

        $hospital = Hospital::with([
            'doctors:id,name,email,phone,specialty,license_number,hospital_id,created_at',
            'nurses:id,name,email,phone,license_number,availability_status,hospital_id,created_at',
        ])->findOrFail($user->hospital_id);

        return response()->json([
            'hospital_id' => $hospital->id,
            'hospital_name' => $hospital->name,
            'hospital_status' => $hospital->status,
            'doctors_count' => $hospital->doctors->count(),
            'nurses_count' => $hospital->nurses->count(),
            'doctors' => $hospital->doctors,
            'nurses' => $hospital->nurses,
        ]);
    }

    /**
     * POST /api/my-hospital/doctors
     * Enregistrement d'un nouveau médecin rattaché directement à l'hôpital de l'administrateur.
     */
    public function storeDoctor(Request $request)
    {
        $user = $request->user();
        abort_if(! $user->isAdmin() || ! $user->hospital_id, 403, "Accès réservé aux administrateurs d'hôpital.");

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)],
            'phone' => ['nullable', 'string', 'max:30'],
            'specialty' => ['required', 'string', 'max:255'],
            'license_number' => ['required', 'string', 'max:255'],
        ]);

        $doctor = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'role' => 'doctor',
            'hospital_id' => $user->hospital_id,
            'phone' => $validated['phone'] ?? null,
            'specialty' => $validated['specialty'],
            'license_number' => $validated['license_number'],
        ]);

        return response()->json([
            'message' => "Médecin {$doctor->name} enregistré avec succès au sein de l'établissement.",
            'doctor' => $doctor,
        ], 201);
    }

    /**
     * POST /api/my-hospital/nurses
     * Enregistrement d'un(e) nouvel(le) infirmier(e) rattaché(e) à l'hôpital de l'administrateur.
     */
    public function storeNurse(Request $request)
    {
        $user = $request->user();
        abort_if(! $user->isAdmin() || ! $user->hospital_id, 403, "Accès réservé aux administrateurs d'hôpital.");

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)],
            'phone' => ['nullable', 'string', 'max:30'],
            'license_number' => ['required', 'string', 'max:255'],
        ]);

        $nurse = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'role' => 'nurse',
            'hospital_id' => $user->hospital_id,
            'phone' => $validated['phone'] ?? null,
            'license_number' => $validated['license_number'],
            'availability_status' => 'disponible',
        ]);

        return response()->json([
            'message' => "Infirmier(e) {$nurse->name} enregistré(e) avec succès au sein de l'établissement.",
            'nurse' => $nurse,
        ], 201);
    }
}
