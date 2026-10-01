<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\LabRequest;
use App\Models\LabRequestItem;
use App\Models\LabRequestResult;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class LabRequestController extends Controller
{
    /**
     * GET /api/consultations/{consultation}/lab-requests
     * Récupère tous les bilans d'examens prescrits lors d'une consultation.
     */
    public function indexConsultation(Request $request, Consultation $consultation)
    {
        $user = $request->user();

        if (! $consultation->isParticipant($user) && ! $user->isAdmin()) {
            abort(403, 'Accès non autorisé à cette consultation.');
        }

        $labRequests = LabRequest::where('consultation_id', $consultation->id)
            ->with([
                'items',
                'results.uploader:id,name',
                'doctor:id,name,specialty,hospital_id',
                'doctor.hospital:id,name,address',
                'patient:id,name,date_of_birth,phone',
            ])
            ->latest()
            ->get();

        return response()->json($labRequests);
    }

    /**
     * GET /api/lab-requests/my
     * Récupère la liste de tous les bilans d'examens prescrits au patient ou par le médecin.
     */
    public function indexMine(Request $request)
    {
        $user = $request->user();

        $query = LabRequest::query();

        if ($user->isPatient()) {
            $query->where('patient_id', $user->id);
        } elseif ($user->isDoctor()) {
            $query->where('doctor_id', $user->id);
        } else {
            // Pour les admins / hôpitaux
            if ($user->hospital_id) {
                $query->whereHas('doctor', fn ($q) => $q->where('hospital_id', $user->hospital_id));
            }
        }

        $labRequests = $query->with([
            'items',
            'results.uploader:id,name',
            'doctor:id,name,specialty,hospital_id',
            'doctor.hospital:id,name,address',
            'patient:id,name,date_of_birth,phone',
            'consultation:id,reference_code,diagnosis,created_at',
        ])
        ->latest()
        ->get();

        return response()->json($labRequests);
    }

    /**
     * GET /api/lab-requests/{labRequest}
     * Détail d'une demande de bilans médicaux.
     */
    public function show(Request $request, LabRequest $labRequest)
    {
        $user = $request->user();

        if (! $labRequest->isParticipant($user) && ! $user->isAdmin()) {
            abort(403, 'Accès non autorisé à ce bilan médical.');
        }

        return response()->json(
            $labRequest->load([
                'items',
                'results.uploader:id,name',
                'doctor:id,name,specialty,hospital_id',
                'doctor.hospital:id,name,address',
                'patient:id,name,date_of_birth,phone',
                'consultation:id,reference_code,diagnosis,created_at',
            ])
        );
    }

    /**
     * POST /api/consultations/{consultation}/lab-requests
     * Le praticien prescrit des bilans ou examens complémentaires.
     */
    public function store(Request $request, Consultation $consultation)
    {
        $user = $request->user();

        if (! $user->isDoctor() || $consultation->doctor_id !== $user->id) {
            abort(403, 'Seul le médecin en charge de la consultation peut prescrire des examens complémentaires.');
        }

        abort_if(
            in_array($consultation->status, ['terminee', 'annulee']),
            422,
            'Impossible de prescrire des examens : la consultation est déjà clôturée.'
        );

        $validated = $request->validate([
            'clinical_notes' => ['nullable', 'string', 'max:2000'],
            'urgency_level' => ['nullable', 'string', 'in:normal,urgent'],
            'fasting_required' => ['nullable', 'boolean'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.name' => ['required', 'string', 'max:255'],
            'items.*.category' => ['nullable', 'string', 'in:biologie,imagerie,parasitologie,bacteriologie,autre'],
            'items.*.instructions' => ['nullable', 'string', 'max:500'],
        ]);

        $labRequest = DB::transaction(function () use ($validated, $consultation, $user) {
            $labRequest = LabRequest::create([
                'consultation_id' => $consultation->id,
                'doctor_id' => $user->id,
                'patient_id' => $consultation->patient_id,
                'clinical_notes' => $validated['clinical_notes'] ?? null,
                'urgency_level' => $validated['urgency_level'] ?? 'normal',
                'fasting_required' => $validated['fasting_required'] ?? false,
                'status' => 'prescrit',
            ]);

            foreach ($validated['items'] as $itemData) {
                $labRequest->items()->create([
                    'name' => $itemData['name'],
                    'category' => $itemData['category'] ?? 'biologie',
                    'instructions' => $itemData['instructions'] ?? null,
                ]);
            }

            return $labRequest;
        });

        // Notification envoyée au patient
        NotificationService::send(
            $labRequest->patient,
            'lab_request_created',
            "Le Dr {$user->name} vous a prescrit une ordonnance d'examens complémentaires ({$labRequest->reference_code})."
        );

        return response()->json(
            $labRequest->load([
                'items',
                'results',
                'doctor:id,name,specialty,hospital_id',
                'doctor.hospital:id,name,address',
                'patient:id,name,date_of_birth,phone',
                'consultation:id,reference_code',
            ]),
            201
        );
    }

    /**
     * POST /api/lab-requests/{labRequest}/results
     * Téléversement de compte-rendu ou résultats d'analyses (par le patient ou praticien).
     * Accepte fichier multipart (file) OU base64 (file_base64 + file_name).
     */
    public function uploadResults(Request $request, LabRequest $labRequest)
    {
        $user = $request->user();

        if (! $labRequest->isParticipant($user) && ! $user->isAdmin()) {
            abort(403, 'Accès non autorisé.');
        }

        $validated = $request->validate([
            'patient_notes' => ['nullable', 'string', 'max:1000'],
            'file' => ['nullable', 'file', 'max:15360'], // max 15MB
            'file_base64' => ['nullable', 'string'],
            'file_name' => ['nullable', 'string', 'max:255'],
        ]);

        if (! $request->hasFile('file') && empty($validated['file_base64'])) {
            return response()->json([
                'message' => 'Veuillez joindre au moins un document ou une photo de résultats.',
            ], 422);
        }

        $storedPath = null;
        $originalName = 'resultat_analyse';
        $mimeType = null;
        $fileSize = null;

        if ($request->hasFile('file')) {
            $uploadedFile = $request->file('file');
            $originalName = $uploadedFile->getClientOriginalName();
            $mimeType = $uploadedFile->getMimeType();
            $fileSize = $uploadedFile->getSize();
            
            $storedPath = $uploadedFile->store('lab_results', 'public');
        } elseif (! empty($validated['file_base64'])) {
            $base64Data = $validated['file_base64'];
            $originalName = $validated['file_name'] ?? ('resultat_' . time() . '.jpg');
            
            // Format data URI ? data:image/jpeg;base64,...
            if (preg_match('/^data:(.*?);base64,(.*)$/', $base64Data, $matches)) {
                $mimeType = $matches[1];
                $decoded = base64_decode($matches[2]);
            } else {
                $mimeType = 'image/jpeg';
                $decoded = base64_decode($base64Data);
            }

            $extension = pathinfo($originalName, PATHINFO_EXTENSION) ?: 'jpg';
            $fileName = 'lab_results/' . Str::uuid() . '.' . $extension;
            Storage::disk('public')->put($fileName, $decoded);
            $storedPath = $fileName;
            $fileSize = strlen($decoded);
        }

        $url = Storage::disk('public')->url($storedPath);

        $resultRecord = DB::transaction(function () use ($labRequest, $storedPath, $url, $originalName, $mimeType, $fileSize, $validated, $user) {
            $result = $labRequest->results()->create([
                'file_path' => $url,
                'file_name' => $originalName,
                'mime_type' => $mimeType,
                'file_size' => $fileSize,
                'patient_notes' => $validated['patient_notes'] ?? null,
                'uploaded_by' => $user->id,
            ]);

            $labRequest->update([
                'status' => 'resultats_recus',
                'results_uploaded_at' => now(),
            ]);

            return $result;
        });

        // Alerte envoyée au praticien
        if ($user->id !== $labRequest->doctor_id) {
            NotificationService::send(
                $labRequest->doctor,
                'lab_results_uploaded',
                "Le patient {$user->name} a transmis des résultats d'analyses pour le dossier {$labRequest->reference_code}."
            );
        }

        return response()->json([
            'message' => 'Résultats d’examens enregistrés et transmis au praticien avec succès.',
            'result' => $resultRecord->load('uploader:id,name'),
            'lab_request' => $labRequest->fresh([
                'items',
                'results.uploader:id,name',
                'doctor:id,name,hospital_id',
                'patient:id,name',
            ]),
        ], 201);
    }

    /**
     * POST /api/lab-requests/{labRequest}/review
     * Le praticien valide la prise de connaissance des résultats d'examens.
     */
    public function review(Request $request, LabRequest $labRequest)
    {
        $user = $request->user();

        if (! $user->isDoctor() || $labRequest->doctor_id !== $user->id) {
            abort(403, 'Seul le praticien prescripteur peut valider l’analyse de ce bilan.');
        }

        $validated = $request->validate([
            'doctor_review_notes' => ['nullable', 'string', 'max:2000'],
            'status' => ['nullable', 'string', 'in:analyse_terminee,en_attente_resultats,prescrit'],
        ]);

        $labRequest->update([
            'doctor_review_notes' => $validated['doctor_review_notes'] ?? $labRequest->doctor_review_notes,
            'status' => $validated['status'] ?? 'analyse_terminee',
            'reviewed_at' => now(),
        ]);

        NotificationService::send(
            $labRequest->patient,
            'lab_results_reviewed',
            "Le Dr {$user->name} a examiné les résultats de votre bilan ({$labRequest->reference_code})."
        );

        return response()->json([
            'message' => 'Bilan d’examens validé et archivé par le praticien.',
            'lab_request' => $labRequest->fresh([
                'items',
                'results.uploader:id,name',
                'doctor:id,name,hospital_id',
                'patient:id,name',
            ]),
        ]);
    }
}
