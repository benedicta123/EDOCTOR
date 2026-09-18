<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hospital;
use App\Services\NotificationService;
use Illuminate\Http\Request;

class HospitalVerificationController extends Controller
{
    /**
     * GET /api/admin/hospitals/pending
     * Liste des demandes de vérification d'hôpitaux pour l'équipe eDoctor.
     */
    public function index(Request $request)
    {
        abort_if(! $request->user()->isAdmin() || $request->user()->hospital_id !== null, 403, "Accès réservé aux super-administrateurs de la plateforme.");

        $hospitals = Hospital::where('status', 'en_attente')
            ->with('admins:id,name,email,phone,hospital_id')
            ->latest()
            ->get();

        return response()->json($hospitals);
    }

    /**
     * POST /api/admin/hospitals/{hospital}/verify
     */
    public function verify(Request $request, Hospital $hospital)
    {
        abort_if(! $request->user()->isAdmin() || $request->user()->hospital_id !== null, 403, "Accès réservé aux super-administrateurs de la plateforme.");

        $hospital->update([
            'status' => 'verifie',
            'verified_at' => now(),
            'rejected_reason' => null,
        ]);

        // Notifier les administrateurs de l'hôpital
        foreach ($hospital->admins as $admin) {
            NotificationService::send(
                $admin,
                'hospital_verified',
                "Félicitations ! L'établissement {$hospital->name} a été officiellement vérifié et activé sur eDoctor."
            );
        }

        return response()->json([
            'message' => "L'établissement {$hospital->name} a été validé avec succès.",
            'hospital' => $hospital,
        ]);
    }

    /**
     * POST /api/admin/hospitals/{hospital}/reject
     */
    public function reject(Request $request, Hospital $hospital)
    {
        abort_if(! $request->user()->isAdmin() || $request->user()->hospital_id !== null, 403, "Accès réservé aux super-administrateurs de la plateforme.");

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        $hospital->update([
            'status' => 'rejete',
            'rejected_reason' => $validated['reason'],
        ]);

        // Notifier les administrateurs de l'hôpital
        foreach ($hospital->admins as $admin) {
            NotificationService::send(
                $admin,
                'hospital_rejected',
                "Votre demande d'adhésion pour {$hospital->name} a été refusée pour le motif suivant : {$validated['reason']}"
            );
        }

        return response()->json([
            'message' => "L'établissement {$hospital->name} a été rejeté.",
            'hospital' => $hospital,
        ]);
    }

    /**
     * POST /api/dev/hospitals/{hospital}/quick-verify
     * Validation instantanée en 1 clic réservée à l'environnement local/test.
     */
    public function quickVerify(Hospital $hospital)
    {
        abort_if(! app()->environment('local', 'testing'), 403, "Cet endpoint n'est disponible qu'en environnement de développement.");

        $hospital->update([
            'status' => 'verifie',
            'verified_at' => now(),
            'rejected_reason' => null,
        ]);

        return response()->json([
            'message' => "Hôpital {$hospital->name} auto-vérifié instantanément (mode dev).",
            'hospital' => $hospital,
        ]);
    }
}
