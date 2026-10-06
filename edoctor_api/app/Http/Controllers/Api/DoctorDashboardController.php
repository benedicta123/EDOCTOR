<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\Prescription;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class DoctorDashboardController extends Controller
{
    public function dashboard(Request $request)
    {
        Consultation::closeExpiredConsultations();

        $doctor = $this->doctor($request);
        $consultations = Consultation::where('doctor_id', $doctor->id)->visibleToDoctor();

        return response()->json([
            'pending_consultations' => (clone $consultations)->where('status', 'en_attente')->count(),
            'today_consultations' => (clone $consultations)->whereDate('scheduled_at', today())->count(),
            'ongoing_consultations' => (clone $consultations)->where('status', 'en_cours')->count(),
            'completed_consultations' => (clone $consultations)->where('status', 'terminee')->count(),
            'patients_followed' => (clone $consultations)->whereIn('status', ['en_cours', 'terminee'])->distinct('patient_id')->count('patient_id'),
            'prescriptions_issued' => Prescription::where('doctor_id', $doctor->id)->count(),
            'unread_notifications' => $doctor->notifications()->where('read', false)->count(),
            'recent_consultations' => (clone $consultations)
                ->with([
                    'patient:id,name,email,phone,date_of_birth',
                    'doctor:id,name,hospital_id',
                    'doctor.hospital:id,name',
                    'prescription.items.medication',
                    'prescription.doctor.hospital',
                    'prescription.patient',
                ])
                ->orderByRaw("CASE WHEN status = 'en_cours' THEN 1 WHEN status = 'en_attente' THEN 2 ELSE 3 END")
                ->latest()
                ->limit(5)
                ->get(),
        ]);
    }

    public function patients(Request $request)
    {
        $doctor = $this->doctor($request);
        $query = User::query()
            ->where('role', 'patient')
            ->whereHas('patientConsultations', function ($q) use ($doctor) {
                $q->where('doctor_id', $doctor->id)
                    ->whereIn('status', ['en_cours', 'terminee']);
            })
            ->withCount(['patientConsultations as consultations_count' => function ($q) use ($doctor) {
                $q->where('doctor_id', $doctor->id)
                    ->whereIn('status', ['en_cours', 'terminee']);
            }]);

        if ($request->filled('search')) {
            $search = $request->string('search')->toString();
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        if ($request->filled('from')) {
            $query->whereHas('patientConsultations', function ($q) use ($doctor, $request) {
                $q->where('doctor_id', $doctor->id)
                    ->whereIn('status', ['en_cours', 'terminee'])
                    ->whereDate('created_at', '>=', $request->date('from'));
            });
        }

        if ($request->filled('to')) {
            $query->whereHas('patientConsultations', function ($q) use ($doctor, $request) {
                $q->where('doctor_id', $doctor->id)
                    ->whereIn('status', ['en_cours', 'terminee'])
                    ->whereDate('created_at', '<=', $request->date('to'));
            });
        }

        return response()->json($query->orderBy('name')->paginate(20));
    }

    public function profile(Request $request)
    {
        return response()->json($this->doctor($request));
    }

    public function updateProfile(Request $request)
    {
        $doctor = $this->doctor($request);
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'specialty' => ['sometimes', 'string', 'max:255'],
            'license_number' => ['sometimes', 'string', 'max:255'],
            'consultation_fee' => ['sometimes', 'nullable', 'numeric', 'min:500'],
        ]);
        $doctor->update($validated);
        return response()->json($doctor->fresh(['hospital']));
    }

    public function availability(Request $request)
    {
        $doctor = $this->doctor($request);
        $validated = $request->validate([
            'availability_status' => ['required', Rule::in(['disponible', 'indisponible', 'en_consultation'])],
        ]);
        abort_if($validated['availability_status'] === 'en_consultation' && ! $doctor->consultations()->where('status', 'en_cours')->exists(), 422, 'Aucune consultation en cours.');
        $doctor->update($validated);
        return response()->json($doctor->fresh());
    }

    private function doctor(Request $request): User
    {
        abort_unless($request->user()?->isDoctor(), 403, 'Accès réservé aux médecins.');
        return $request->user();
    }
}
