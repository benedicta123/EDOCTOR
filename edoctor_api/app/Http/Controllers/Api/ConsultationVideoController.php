<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Services\JaasService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

/**
 * Accès sécurisé à la salle vidéo JaaS d'une consultation.
 *
 * POST /api/consultations/{consultation}/join
 */
class ConsultationVideoController extends Controller
{
    public function join(
        Request $request,
        Consultation $consultation,
        JaasService $jaas
    ) {
        // 1. Seuls le patient et le médecin de CETTE consultation.
        Gate::authorize('view', $consultation);

        // 2. Consultation valide : ni terminée ni annulée.
        abort_if(
            in_array($consultation->status, ['terminee', 'annulee']),
            422,
            'Cette consultation est clôturée.'
        );

        // 3-5. Domaine + salle + JWT générés côté serveur.
        return response()->json(
            $jaas->joinPayload($consultation, $request->user())
        );
    }
}
