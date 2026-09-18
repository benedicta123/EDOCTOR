<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class ConsultationController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        $consultations = Consultation::where('patient_id', $user->id)
            ->orWhere('doctor_id', $user->id)
            ->with(['patient:id,name', 'doctor:id,name'])
            ->latest()
            ->get();

        return response()->json($consultations);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'doctor_id' => ['required', 'integer', 'exists:users,id'],
            'scheduled_at' => ['nullable', 'date'],
        ]);

        $doctor = User::whereKey($validated['doctor_id'])
            ->where('role', 'doctor')
            ->whereHas('hospital', fn ($q) => $q->where('status', 'verifie'))
            ->firstOrFail();

        $consultation = Consultation::create([
            'patient_id' => $request->user()->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => $validated['scheduled_at'] ?? null,
            'status' => 'en_attente',
        ]);

        NotificationService::send(
            $consultation->doctor,
            'consultation_request',
            "Nouvelle demande de consultation de la part de {$request->user()->name}."
        );

        return response()->json($consultation, 201);
    }

    public function start(Request $request, Consultation $consultation)
    {
        Gate::authorize('start', $consultation);

        DB::transaction(function () use ($consultation) {
            $consultation->update(['status' => 'en_cours', 'started_at' => now()]);
            $consultation->doctor->update(['availability_status' => 'en_consultation']);
        });

        NotificationService::send(
            $consultation->patient,
            'consultation_started',
            "Le Dr {$consultation->doctor->name} a démarré la consultation."
        );

        return response()->json($consultation);
    }

    public function decline(Request $request, Consultation $consultation)
    {
        Gate::authorize('decline', $consultation);

        DB::transaction(function () use ($consultation) {
            $consultation->update(['status' => 'annulee']);
            if ($consultation->doctor->availability_status === 'en_consultation') {
                $consultation->doctor->update(['availability_status' => null]);
            }
        });

        NotificationService::send(
            $consultation->patient,
            'consultation_declined',
            "Le Dr {$consultation->doctor->name} a décliné votre demande de consultation."
        );

        return response()->json($consultation);
    }

    public function end(Request $request, Consultation $consultation)
    {
        Gate::authorize('end', $consultation);

        abort_if(in_array($consultation->status, ['terminee', 'annulee']), 422, 'Cette consultation est déjà clôturée.');

        $validated = $request->validate([
            'diagnosis' => ['nullable', 'string', 'max:5000'],
        ]);

        DB::transaction(function () use ($consultation, $validated) {
            $consultation->update([
                'status' => 'terminee',
                'ended_at' => now(),
                'diagnosis' => $validated['diagnosis'] ?? $consultation->diagnosis,
            ]);
            $consultation->doctor->update(['availability_status' => null]);
        });

        NotificationService::send(
            $consultation->patient,
            'consultation_ended',
            "Votre consultation avec le Dr {$consultation->doctor->name} est terminée."
        );

        return response()->json($consultation);
    }

    public function cancel(Request $request, Consultation $consultation)
    {
        Gate::authorize('cancel', $consultation);

        DB::transaction(function () use ($consultation) {
            $consultation->update(['status' => 'annulee']);
            if ($consultation->doctor->availability_status === 'en_consultation') {
                $consultation->doctor->update(['availability_status' => null]);
            }
        });

        $recipient = $request->user()->id === $consultation->patient_id
            ? $consultation->doctor
            : $consultation->patient;

        NotificationService::send(
            $recipient,
            'consultation_cancelled',
            "La consultation a été annulée par {$request->user()->name}."
        );

        return response()->json($consultation);
    }
}
