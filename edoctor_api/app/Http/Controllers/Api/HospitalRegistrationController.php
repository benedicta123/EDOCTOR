<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hospital;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Illuminate\Validation\Rules\Password;
use App\Services\GeocodingService;

class HospitalRegistrationController extends Controller
{
    /**
     * POST /api/hospitals/register
     * Inscription simultanée (Shopify-like) d'un établissement hospitalier et de son compte Administrateur principal.
     */
    public function register(Request $request, GeocodingService $geocoding)
    {
        $validated = $request->validate([
            // Données de l'établissement
            'hospital_name' => ['required', 'string', 'max:255'],
            'address' => ['required', 'string', 'max:255'],
            'latitude' => ['nullable', 'required_with:longitude', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'required_with:latitude', 'numeric', 'between:-180,180'],
            'license_number' => ['required', 'string', 'max:255'],
            'tax_number' => ['nullable', 'string', 'max:255'],
            'official_email' => ['required', 'string', 'email', 'max:255', 'unique:hospitals,official_email'],
            'hospital_phone' => ['required', 'string', 'max:30'],
            'license_document' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
            'consultation_fee' => ['nullable', 'numeric', 'min:500'],

            // Données du compte Super-Administrateur
            'admin_name' => ['required', 'string', 'max:255'],
            'admin_email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)],
            'admin_phone' => ['nullable', 'string', 'max:30'],

            // Option dev/testing
            'auto_verify' => ['nullable', 'boolean'],
        ]);

        $coordinates = $this->resolveCoordinates($validated, $geocoding);

        $documentPath = null;
        if ($request->hasFile('license_document')) {
            $documentPath = $request->file('license_document')->store('hospital_documents', 'public');
        }

        // Auto-validation acceptée uniquement en environnement local ou de test
        $autoVerify = app()->environment('local', 'testing') && $request->boolean('auto_verify', false);
        $initialStatus = $autoVerify ? 'verifie' : 'en_attente';
        $verifiedAt = $autoVerify ? now() : null;

        $result = DB::transaction(function () use ($validated, $documentPath, $initialStatus, $verifiedAt, $coordinates) {
            $hospital = Hospital::create([
                'name' => $validated['hospital_name'],
                'address' => $validated['address'],
                'latitude' => $coordinates['latitude'],
                'longitude' => $coordinates['longitude'],
                'status' => $initialStatus,
                'license_number' => $validated['license_number'],
                'tax_number' => $validated['tax_number'] ?? null,
                'official_email' => $validated['official_email'],
                'phone' => $validated['hospital_phone'],
                'license_document_path' => $documentPath,
                'verified_at' => $verifiedAt,
                'consultation_fee' => $validated['consultation_fee'] ?? (float) config('monetization.consultation.default_hospital_fee', 3000.0),
            ]);

            $admin = User::create([
                'name' => $validated['admin_name'],
                'email' => $validated['admin_email'],
                'password' => Hash::make($validated['password']),
                'role' => 'admin',
                'hospital_id' => $hospital->id,
                'phone' => $validated['admin_phone'] ?? null,
            ]);

            $token = $admin->createAccessToken('admin-api-token')->plainTextToken;

            return [
                'hospital' => $hospital,
                'admin' => $admin,
                'token' => $token,
            ];
        });

        return response()->json([
            'message' => $autoVerify
                ? 'Hôpital et compte Administrateur créés et vérifiés automatiquement (mode dev).'
                : 'Hôpital et compte Administrateur créés avec succès. Votre établissement est en attente de vérification.',
            'hospital' => $result['hospital'],
            'admin' => $result['admin'],
            'token' => $result['token'],
        ], 201);
    }

    public function geocode(Request $request, GeocodingService $geocoding)
    {
        $validated = $request->validate([
            'address' => ['required_without:latitude', 'nullable', 'string', 'max:255'],
            'latitude' => ['required_without:address', 'nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['required_with:latitude', 'nullable', 'numeric', 'between:-180,180'],
        ]);

        try {
            if (isset($validated['latitude'], $validated['longitude'])) {
                $address = $geocoding->reverse((float) $validated['latitude'], (float) $validated['longitude']);
                return response()->json([
                    'latitude' => (float) $validated['latitude'],
                    'longitude' => (float) $validated['longitude'],
                    'address' => $address,
                ]);
            }

            $result = $geocoding->geocode($validated['address']);
            if ($result === null) {
                throw ValidationException::withMessages([
                    'address' => 'Adresse introuvable. Choisissez la position sur la carte.',
                ]);
            }

            return response()->json($result);
        } catch (ValidationException $exception) {
            throw $exception;
        } catch (\Throwable) {
            throw ValidationException::withMessages([
                'address' => 'Adresse non localisable pour le moment. Choisissez la position sur la carte.',
            ]);
        }
    }

    private function resolveCoordinates(array $validated, GeocodingService $geocoding): array
    {
        if (isset($validated['latitude'], $validated['longitude'])) {
            return [
                'latitude' => (float) $validated['latitude'],
                'longitude' => (float) $validated['longitude'],
            ];
        }

        try {
            $result = $geocoding->geocode($validated['address']);
        } catch (\Throwable) {
            $result = null;
        }

        if ($result === null) {
            throw ValidationException::withMessages([
                'address' => 'Adresse non localisable. Choisissez votre position sur la carte avant de continuer.',
            ]);
        }

        return [
            'latitude' => $result['latitude'],
            'longitude' => $result['longitude'],
        ];
    }

    /**
     * GET /api/my-hospital
     * Espace de l'administrateur d'hôpital connecté.
     */
    public function myHospital(Request $request)
    {
        $user = $request->user();
        abort_if(! $user->isAdmin() || ! $user->hospital_id, 403, "Accès réservé aux administrateurs d'hôpital.");

        $hospital = Hospital::with(['doctors', 'nurses', 'nurseVisits'])->findOrFail($user->hospital_id);

        return response()->json($hospital);
    }
}
