<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\Prescription;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class PrescriptionController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        $prescriptions = Prescription::where('patient_id', $user->id)
            ->orWhere('doctor_id', $user->id)
            ->with([
                'items.medication',
                'doctor:id,name,hospital_id',
                'doctor.hospital:id,name,address',
                'patient:id,name,date_of_birth,phone',
                'consultation:id,reference_code,diagnosis,created_at',
            ])
            ->latest()
            ->get();

        return response()->json($prescriptions);
    }

    public function show(Request $request, Prescription $prescription)
    {
        Gate::authorize('view', $prescription);

        return response()->json(
            $prescription->load([
                'items.medication',
                'doctor:id,name,hospital_id',
                'doctor.hospital:id,name,address',
                'patient:id,name,date_of_birth,phone',
                'consultation:id,reference_code,diagnosis,created_at',
            ])
        );
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'consultation_id' => ['required', 'exists:consultations,id'],
            'home_care_recommended' => ['boolean'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.medication_id' => ['required', 'exists:medications,id'],
            'items.*.dosage_instructions' => ['required', 'string', 'max:255'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
        ]);

        $consultation = Consultation::findOrFail($validated['consultation_id']);

        Gate::authorize('create', [Prescription::class, $consultation]);

        abort_if(
            in_array($consultation->status, ['terminee', 'annulee']),
            422,
            'Impossible de rédiger une ordonnance : cette consultation est clôturée.'
        );

        $prescription = DB::transaction(function () use ($validated, $consultation, $request) {
            $prescription = Prescription::create([
                'consultation_id' => $consultation->id,
                'doctor_id' => $request->user()->id,
                'patient_id' => $consultation->patient_id,
                'status' => 'validee',
                'home_care_recommended' => $validated['home_care_recommended'] ?? false,
            ]);

            foreach ($validated['items'] as $item) {
                $prescription->items()->create($item);
            }

            return $prescription;
        });

        NotificationService::send(
            $prescription->patient,
            'prescription_created',
            "Le Dr {$request->user()->name} a émis une nouvelle ordonnance pour votre consultation."
        );

        return response()->json($prescription->load('items.medication'), 201);
    }

    public function cancel(Request $request, Prescription $prescription)
    {
        Gate::authorize('cancel', $prescription);

        if ($prescription->status === 'annulee') {
            abort(422, 'Cette ordonnance est déjà annulée.');
        }

        // Règle médico-légale : interdiction formelle d'annuler au-delà de 5 minutes après l'émission
        if ($prescription->created_at && $prescription->created_at->diffInMinutes(now()) >= 5) {
            abort(422, 'Impossible d’annuler cette ordonnance : le délai réglementaire de 5 minutes après émission est dépassé (règle médico-légale de traçabilité pharmaceutique).');
        }

        $prescription->update(['status' => 'annulee']);

        NotificationService::send(
            $prescription->patient,
            'prescription_cancelled',
            "L'ordonnance #{$prescription->id} a été annulée par le Dr {$request->user()->name}."
        );

        return response()->json($prescription);
    }
}
