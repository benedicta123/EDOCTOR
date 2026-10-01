<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\Prescription;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class PatientDossierController extends Controller
{
    public function show(Request $request, User $patient)
    {
        abort_if(! $patient->isPatient(), 404);

        Gate::authorize('viewPatientDossier', $patient);

        $consultations = Consultation::where('patient_id', $patient->id)
            ->whereIn('status', ['en_cours', 'terminee'])
            ->with([
                'doctor:id,name,specialty,hospital_id',
                'doctor.hospital:id,name,address',
                'prescription.items.medication',
                'prescription.doctor:id,name',
            ])
            ->latest()
            ->get();

        $prescriptions = Prescription::where('patient_id', $patient->id)
            ->where('status', 'validee')
            ->with([
                'items.medication',
                'doctor:id,name,hospital_id',
                'doctor.hospital:id,name,address',
            ])
            ->latest()
            ->get();

        $labRequests = \App\Models\LabRequest::where('patient_id', $patient->id)
            ->with([
                'items',
                'results.uploader:id,name',
                'doctor:id,name,hospital_id',
                'doctor.hospital:id,name,address',
                'consultation:id,reference_code,diagnosis,created_at',
            ])
            ->latest()
            ->get();

        return response()->json([
            'patient' => $patient->only(['id', 'name', 'date_of_birth', 'address', 'medical_history_summary']),
            'consultations' => $consultations,
            'prescriptions' => $prescriptions,
            'lab_requests' => $labRequests,
        ]);
    }
}
