<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hospital;
use App\Models\NurseVisit;
use App\Models\Prescription;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

class NurseVisitController extends Controller
{
    public function store(Request $request, Prescription $prescription)
    {
        Gate::authorize('requestNurseVisit', $prescription);

        abort_if($prescription->nurseVisit()->exists(), 422,
            "Une visite a déjà été demandée pour cette prescription.");

        $hospitalId = $prescription->doctor->hospital_id;

        abort_if(! $hospitalId, 422, "Le médecin prescripteur n'est rattaché à aucun hôpital.");

        $visit = NurseVisit::create([
            'prescription_id' => $prescription->id,
            'patient_id' => $prescription->patient_id,
            'hospital_id' => $hospitalId,
            'status' => 'en_attente',
        ]);

        $admins = User::where('hospital_id', $hospitalId)->whereIn('role', ['admin', 'hospital_admin'])->get();
        foreach ($admins as $admin) {
            NotificationService::send(
                $admin,
                'nurse_visit_requested',
                "Nouvelle demande de soins à domicile pour la prescription #{$prescription->id}."
            );
        }

        return response()->json($visit, 201);
    }

    public function index(Request $request, Hospital $hospital)
    {
        abort_if(! $request->user()->isAdmin() || $request->user()->hospital_id !== $hospital->id, 403);

        $query = $hospital->nurseVisits()->with(['patient:id,name', 'prescription.doctor:id,name']);

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        return response()->json($query->latest()->get());
    }

    public function assign(Request $request, NurseVisit $nurseVisit)
    {
        Gate::authorize('manageAsHospitalAdmin', $nurseVisit);

        $validated = $request->validate([
            'nurse_id' => ['required', 'integer', 'exists:users,id'],
        ]);

        DB::transaction(function () use ($validated, $nurseVisit) {
            $nurse = User::where('id', $validated['nurse_id'])
                ->where('role', 'nurse')
                ->where('hospital_id', $nurseVisit->hospital_id)
                ->where('availability_status', 'disponible')
                ->lockForUpdate()
                ->firstOrFail();

            $nurse->update(['availability_status' => 'en_mission']);

            $nurseVisit->update(['nurse_id' => $nurse->id, 'status' => 'assignee']);
        });

        $nurseVisit->load(['nurse:id,name,phone', 'patient:id,name']);

        if ($nurseVisit->nurse) {
            NotificationService::send(
                $nurseVisit->nurse,
                'nurse_visit_assigned',
                "Une visite de soins à domicile vous a été assignée (Patient : {$nurseVisit->patient->name})."
            );
        }

        if ($nurseVisit->patient) {
            NotificationService::send(
                $nurseVisit->patient,
                'nurse_visit_assigned',
                "Votre visite à domicile a été assignée à l'infirmier(e) {$nurseVisit->nurse->name}."
            );
        }

        return response()->json($nurseVisit);
    }

    public function accept(Request $request, NurseVisit $nurseVisit)
    {
        Gate::authorize('respond', $nurseVisit);

        $nurseVisit->update(['status' => 'en_route']);

        $nurseVisit->load(['nurse:id,name', 'patient']);
        if ($nurseVisit->patient) {
            NotificationService::send(
                $nurseVisit->patient,
                'nurse_en_route',
                "L'infirmier(e) {$nurseVisit->nurse->name} est en route pour vos soins à domicile."
            );
        }

        return response()->json($nurseVisit);
    }

    public function decline(Request $request, NurseVisit $nurseVisit)
    {
        Gate::authorize('respond', $nurseVisit);

        DB::transaction(function () use ($nurseVisit) {
            $nurseVisit->nurse()->update(['availability_status' => 'disponible']);
            $nurseVisit->update(['nurse_id' => null, 'status' => 'en_attente']);
        });

        $admins = User::where('hospital_id', $nurseVisit->hospital_id)->where('role', 'admin')->get();
        foreach ($admins as $admin) {
            NotificationService::send(
                $admin,
                'nurse_visit_declined',
                "La visite à domicile #{$nurseVisit->id} a été déclinée par l'infirmier(e) et attend une nouvelle affectation."
            );
        }

        return response()->json($nurseVisit);
    }

    public function myVisits(Request $request)
    {
        $user = $request->user();

        if ($user->isNurse()) {
            $visits = NurseVisit::where('nurse_id', $user->id)
                ->with([
                    'patient:id,name,phone,email,address,date_of_birth',
                    'prescription.doctor:id,name,phone',
                    'prescription.items.medication',
                    'hospital:id,name,phone,address',
                ])
                ->latest()
                ->get();
            return response()->json($visits);
        }

        if ($user->isPatient()) {
            $visits = NurseVisit::where('patient_id', $user->id)
                ->with([
                    'nurse:id,name,phone',
                    'prescription.doctor:id,name,phone',
                    'prescription.items.medication',
                    'hospital:id,name,phone,address',
                ])
                ->latest()
                ->get();
            return response()->json($visits);
        }

        abort(403, 'Accès non autorisé.');
    }

    public function complete(Request $request, NurseVisit $nurseVisit)
    {
        Gate::authorize('respond', $nurseVisit);

        $validated = $request->validate([
            'report' => ['nullable', 'string', 'max:5000'],
            'blood_pressure' => ['nullable', 'string', 'max:50'],
            'blood_glucose' => ['nullable', 'string', 'max:50'],
            'temperature' => ['nullable', 'string', 'max:50'],
            'heart_rate' => ['nullable', 'string', 'max:50'],
            'acts_performed' => ['nullable', 'array'],
        ]);

        DB::transaction(function () use ($nurseVisit, $validated) {
            $nurseVisit->nurse()->update(['availability_status' => 'disponible']);
            $nurseVisit->update([
                'status' => 'terminee',
                'report' => $validated['report'] ?? $nurseVisit->report,
                'blood_pressure' => $validated['blood_pressure'] ?? null,
                'blood_glucose' => $validated['blood_glucose'] ?? null,
                'temperature' => $validated['temperature'] ?? null,
                'heart_rate' => $validated['heart_rate'] ?? null,
                'acts_performed' => $validated['acts_performed'] ?? null,
                'completed_at' => now(),
            ]);
        });

        $nurseVisit->load(['patient', 'nurse']);
        if ($nurseVisit->patient) {
            NotificationService::send(
                $nurseVisit->patient,
                'nurse_visit_completed',
                "Votre visite de soins à domicile est terminée. Le compte-rendu et vos constantes ont été enregistrés."
            );
        }

        return response()->json($nurseVisit);
    }
}
