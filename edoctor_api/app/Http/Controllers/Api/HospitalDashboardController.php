<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\Hospital;
use App\Models\NurseVisit;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class HospitalDashboardController extends Controller
{
    public function dashboard(Request $request)
    {
        $admin = $this->admin($request);
        $hospitalId = $admin->hospital_id;
        $doctorIds = User::where('hospital_id', $hospitalId)->where('role', 'doctor')->pluck('id');
        $consultations = Consultation::whereIn('doctor_id', $doctorIds);
        $visits = NurseVisit::where('hospital_id', $hospitalId);

        return response()->json([
            'hospital_status' => $admin->hospital->status,
            'doctors_count' => User::whereIn('id', $doctorIds)->count(),
            'nurses_count' => User::where('hospital_id', $hospitalId)->where('role', 'nurse')->count(),
            'today_consultations' => (clone $consultations)->whereDate('scheduled_at', today())->count(),
            'ongoing_consultations' => (clone $consultations)->where('status', 'en_cours')->count(),
            'pending_home_visits' => (clone $visits)->where('status', 'en_attente')->count(),
            'completed_home_visits' => (clone $visits)->where('status', 'terminee')->count(),
            'recent_notifications' => $admin->notifications()->latest()->limit(8)->get(),
        ]);
    }

    public function consultations(Request $request)
    {
        $admin = $this->admin($request);
        $doctorIds = User::where('hospital_id', $admin->hospital_id)->where('role', 'doctor')->pluck('id');
        $query = Consultation::whereIn('doctor_id', $doctorIds)
            ->with(['patient:id,name,email,phone', 'doctor:id,name,specialty']);
        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }
        return response()->json($query->latest()->paginate(25));
    }

    public function statistics(Request $request)
    {
        $admin = $this->admin($request);
        $doctorIds = User::where('hospital_id', $admin->hospital_id)->where('role', 'doctor')->pluck('id');
        $base = Consultation::whereIn('doctor_id', $doctorIds);
        return response()->json([
            'consultations_total' => (clone $base)->count(),
            'consultations_completed' => (clone $base)->where('status', 'terminee')->count(),
            'consultations_cancelled' => (clone $base)->where('status', 'annulee')->count(),
            'unique_patients' => (clone $base)->distinct('patient_id')->count('patient_id'),
            'prescriptions_total' => \App\Models\Prescription::whereIn('doctor_id', $doctorIds)->count(),
            'visits_total' => NurseVisit::where('hospital_id', $admin->hospital_id)->count(),
        ]);
    }

    public function updateHospital(Request $request)
    {
        $admin = $this->admin($request);
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'address' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'string', 'max:30'],
            'official_email' => ['sometimes', 'email', 'max:255', Rule::unique('hospitals', 'official_email')->ignore($admin->hospital_id)],
            'latitude' => ['sometimes', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'numeric', 'between:-180,180'],
        ]);
        $admin->hospital->update($validated);
        return response()->json($admin->hospital->fresh());
    }

    private function admin(Request $request): User
    {
        abort_unless($request->user()?->isAdmin() && $request->user()->hospital_id, 403, 'Accès réservé aux administrateurs d’hôpital.');
        return $request->user()->load('hospital');
    }
}
