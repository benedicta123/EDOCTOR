<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Pharmacy;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class PharmacyRegistrationController extends Controller
{
    /**
     * POST /api/pharmacies/register
     * Inscription d'une officine de pharmacie et de son Pharmacien Titulaire avec statut initial "en_attente".
     */
    public function register(Request $request)
    {
        $validated = $request->validate([
            // Étape 1 : Établissement
            'pharmacy_name' => ['required', 'string', 'max:255'],
            'city' => ['required', 'string', 'max:100'],
            'address' => ['required', 'string', 'max:255'],
            'pharmacy_phone' => ['required', 'string', 'max:30'],
            'official_email' => ['required', 'string', 'email', 'max:255'],

            // Étape 2 : Responsable Légal
            'pharmacist_name' => ['required', 'string', 'max:255'],
            'order_number' => ['required', 'string', 'max:100'],
            'license_number' => ['required', 'string', 'max:100'],
            'mobile_phone' => ['required', 'string', 'max:30'],
            'pharmacist_email' => ['nullable', 'string', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:8'],

            // Étape 3 : Documents / Fichiers optionnels
            'documents' => ['nullable', 'array'],
        ]);

        $accountEmail = $validated['pharmacist_email'] ?? $validated['official_email'];

        // Vérifier si l'utilisateur existe déjà
        if (User::where('email', $accountEmail)->exists()) {
            return response()->json([
                'message' => "Un compte utilisateur existe déjà avec l'adresse email {$accountEmail}. Veuillez vous connecter ou utiliser une autre adresse.",
            ], 422);
        }

        // Génération d'une référence unique : KYP-2026-TG + 3 chiffres/lettres aléatoires
        $referenceId = 'KYP-2026-TG' . strtoupper(Str::random(4));

        $result = DB::transaction(function () use ($validated, $accountEmail, $referenceId) {
            $user = User::create([
                'name' => $validated['pharmacist_name'],
                'email' => $accountEmail,
                'password' => Hash::make($validated['password']),
                'role' => 'pharmacist',
                'phone' => $validated['mobile_phone'],
            ]);

            $fullAddress = trim($validated['address'] . ', ' . $validated['city']);

            $pharmacy = Pharmacy::create([
                'owner_id' => $user->id,
                'reference_id' => $referenceId,
                'name' => $validated['pharmacy_name'],
                'status' => 'en_attente',
                'license_number' => $validated['license_number'],
                'order_number' => $validated['order_number'],
                'official_email' => $validated['official_email'],
                'address' => $fullAddress,
                'phone' => $validated['pharmacy_phone'],
                'documents' => $validated['documents'] ?? null,
                'latitude' => null,
                'longitude' => null,
            ]);

            return [
                'user' => $user,
                'pharmacy' => $pharmacy,
            ];
        });

        return response()->json([
            'message' => "Votre dossier d'agrément a été enregistré avec succès et est en attente d'audit par la Conformité eDoctor.",
            'reference_id' => $referenceId,
            'status' => 'en_attente',
            'pharmacy' => [
                'id' => $result['pharmacy']->id,
                'reference_id' => $referenceId,
                'name' => $result['pharmacy']->name,
                'pharmacist_name' => $result['user']->name,
                'order_number' => $result['pharmacy']->order_number,
                'official_email' => $result['pharmacy']->official_email,
                'status' => $result['pharmacy']->status,
                'created_at' => $result['pharmacy']->created_at,
            ],
        ], 201);
    }

    /**
     * POST /api/pharmacies/track-status
     * Vérifie si un identifiant ou une adresse email correspond bien à un dossier d'agrément en base de données.
     */
    public function trackStatus(Request $request)
    {
        $request->validate([
            'query' => ['required', 'string', 'max:255'],
        ]);

        $query = trim($request->input('query'));

        // 1. Recherche directe par référence de dossier (ex: KYP-2026-TG...) ou email officiel de l'officine
        $pharmacy = Pharmacy::with('owner')
            ->where('reference_id', $query)
            ->orWhere('official_email', $query)
            ->first();

        // 2. Si non trouvée, recherche par l'email du compte utilisateur pharmacien
        if (!$pharmacy) {
            $user = User::where('email', $query)->where('role', 'pharmacist')->first();
            if ($user) {
                $pharmacy = Pharmacy::with('owner')->where('owner_id', $user->id)->first();
            }
        }

        // 3. Si toujours non trouvée, tentative de recherche par numéro d'Ordre ou nom exact
        if (!$pharmacy) {
            $pharmacy = Pharmacy::with('owner')
                ->where('order_number', $query)
                ->orWhere('name', $query)
                ->first();
        }

        // 4. Si inexistant en base de données -> Erreur 404 explicite
        if (!$pharmacy) {
            return response()->json([
                'found' => false,
                'message' => "Aucun dossier d'agrément ne correspond à cet identifiant ou cette adresse email (\"{$query}\"). Veuillez vérifier votre saisie ou soumettre une nouvelle inscription.",
            ], 404);
        }

        // Détermination de l'étape de progression (1 à 4)
        $step = 2; // Par défaut : audit des pièces
        if ($pharmacy->status === 'verifie') {
            $step = 4;
        } elseif ($pharmacy->status === 'rejete') {
            $step = 2;
        }

        $ref = $pharmacy->reference_id ?? ('KYP-2026-TG' . str_pad($pharmacy->id, 4, '0', STR_PAD_LEFT));

        return response()->json([
            'found' => true,
            'reference_id' => $ref,
            'pharmacy_name' => $pharmacy->name,
            'pharmacist_name' => $pharmacy->owner ? $pharmacy->owner->name : 'Pharmacien Titulaire',
            'order_number' => $pharmacy->order_number ?? 'ONPT-N/A',
            'official_email' => $pharmacy->official_email ?? ($pharmacy->owner ? $pharmacy->owner->email : ''),
            'status' => $pharmacy->status, // 'en_attente', 'verifie', 'rejete'
            'step' => $step,
            'submitted_at' => $pharmacy->created_at ? $pharmacy->created_at->toIso8601String() : now()->toIso8601String(),
            'rejected_reason' => $pharmacy->rejected_reason,
            'message' => $pharmacy->status === 'verifie'
                ? "Ce dossier a été validé avec succès par l'équipe eDoctor. Le compte est pleinement opérationnel."
                : "Dossier en cours d'audit par l'équipe Conformité eDoctor.",
        ]);
    }
}
