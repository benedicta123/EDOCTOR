<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Claim;
use App\Models\User;
use App\Services\NotificationService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class ClaimController extends Controller
{
    /**
     * GET /api/claims/my
     * Récupère toutes les réclamations déposées par l'utilisateur connecté (patient ou praticien).
     */
    public function indexMine(Request $request)
    {
        $user = $request->user();

        $claims = Claim::where('user_id', $user->id)
            ->with(['resolver:id,name'])
            ->latest()
            ->get();

        return response()->json($claims);
    }

    /**
     * POST /api/claims
     * Dépôt d'une nouvelle réclamation par un utilisateur authentifié.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'subject' => ['required', 'string', 'min:3', 'max:255'],
            'description' => ['required', 'string', 'min:10', 'max:5000'],
            'category' => ['required', 'string', 'in:medical,pharmacie,livraison,facturation,technique,autre'],
            'priority' => ['nullable', 'string', 'in:faible,normale,haute,urgente'],
            'target_type' => ['nullable', 'string', 'max:50'],
            'target_id' => ['nullable', 'integer'],
        ]);

        $yearMonth = Carbon::now()->format('ym');
        $randomSuffix = strtoupper(Str::random(4));
        $referenceId = "REC-{$yearMonth}-{$randomSuffix}";

        // Vérification de collision rarissime
        while (Claim::where('reference_id', $referenceId)->exists()) {
            $randomSuffix = strtoupper(Str::random(4));
            $referenceId = "REC-{$yearMonth}-{$randomSuffix}";
        }

        $claim = Claim::create([
            'reference_id' => $referenceId,
            'user_id' => $request->user()->id,
            'target_type' => $validated['target_type'] ?? 'platform',
            'target_id' => $validated['target_id'] ?? null,
            'category' => $validated['category'],
            'priority' => $validated['priority'] ?? 'normale',
            'subject' => $validated['subject'],
            'description' => $validated['description'],
            'status' => 'ouvert',
        ]);

        // Notification aux Super-Admins de la plateforme
        $superAdmins = User::where('role', 'admin')->whereNull('hospital_id')->get();
        foreach ($superAdmins as $admin) {
            NotificationService::send(
                $admin,
                'new_claim_submitted',
                "Nouvelle réclamation {$referenceId} déposée par {$request->user()->name} ({$validated['subject']})."
            );
        }

        return response()->json([
            'message' => 'Votre réclamation a bien été enregistrée et transmise à nos équipes.',
            'claim' => $claim->load('resolver:id,name'),
        ], 201);
    }
}
