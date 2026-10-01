<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * POST /api/register et POST /api/patients/register
     * Inscription dédiée exclusivement aux patients.
     * Le rôle est systématiquement forcé à "patient".
     * Les soignants (médecins, infirmiers) sont enregistrés par les hôpitaux.
     */
    public function register(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)],
            'phone' => ['nullable', 'string', 'max:30'],
            'date_of_birth' => ['nullable', 'date', 'before:today'],
            'address' => ['nullable', 'string', 'max:255'],
            'medical_history_summary' => ['nullable', 'string', 'max:2000'],
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'role' => 'patient',
            'phone' => $validated['phone'] ?? null,
            'date_of_birth' => $validated['date_of_birth'] ?? null,
            'address' => $validated['address'] ?? null,
            'medical_history_summary' => $validated['medical_history_summary'] ?? null,
        ]);

        $token = $user->createAccessToken('api-token')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ], 201);
    }

    /**
     * POST /api/login
     */
    public function login(Request $request)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (! $user || ! Hash::check($validated['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Identifiants incorrects.'],
            ]);
        }

        if ($user->is_suspended) {
            $reason = $user->suspension_reason ? " : " . $user->suspension_reason : "";
            return response()->json([
                'message' => "Ce compte utilisateur a été suspendu par l'administration eDoctor{$reason}. Veuillez contacter le support de régulation.",
            ], 403);
        }

        if ($user->isPharmacist()) {
            $user->load('pharmacy');
        }

        $token = $user->createAccessToken('api-token')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ]);
    }

    /**
     * POST /api/logout
     * Nécessite d'être authentifié (middleware auth:sanctum).
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Déconnecté.']);
    }

    /**
     * GET /api/me
     * Nécessite d'être authentifié (middleware auth:sanctum).
     */
    public function me(Request $request)
    {
        return response()->json($request->user());
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();
        $rules = [
            'name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
        ];

        if ($user->isDoctor()) {
            $rules['specialty'] = ['sometimes', 'string', 'max:255'];
            $rules['license_number'] = ['sometimes', 'string', 'max:255'];
        }

        $user->update($request->validate($rules));

        return response()->json($user->fresh());
    }
}
