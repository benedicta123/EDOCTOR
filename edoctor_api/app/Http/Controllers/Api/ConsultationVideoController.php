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
        // 1. Clôture automatique si la limite de 2h est atteinte
        if ($consultation->status === 'en_cours' && $consultation->started_at && $consultation->started_at->diffInMinutes(now()) >= 120) {
            Consultation::closeExpiredConsultations();
            abort(422, 'Cette téléconsultation a été automatiquement coupée par le système car la durée maximale autorisée (2 heures) a été atteinte.');
        }

        // 2. Seuls le patient et le médecin de CETTE consultation.
        Gate::authorize('view', $consultation);

        // 3. Consultation valide : ni terminée ni annulée.
        abort_if(
            in_array($consultation->status, ['terminee', 'annulee']),
            422,
            'Cette consultation est clôturée.'
        );

        // 4-5. Domaine + salle + JWT générés côté serveur.
        return response()->json(
            $jaas->joinPayload($consultation, $request->user())
        );
    }
}
