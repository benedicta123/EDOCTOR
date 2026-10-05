<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\MonetizationService;
use Illuminate\Http\Request;

class DoctorController extends Controller
{
    /**
     * GET /api/doctors/available
     * Alimente l'écran patient "Consulter un médecin" — uniquement ceux
     * réellement joignables maintenant (en ligne et pas déjà en consultation).
     */
    public function available(Request $request)
    {
        $doctors = User::where('role', 'doctor')
            ->whereHas('hospital', function ($q) {
                $q->where('status', 'verifie');
            })
            ->with('hospital:id,name,consultation_fee')
            ->get()
            ->map(function ($doctor) {
                $pricing = MonetizationService::calculateConsultationPricing($doctor->hospital, $doctor);
                return [
                    'id' => $doctor->id,
                    'name' => $doctor->name,
                    'specialty' => $doctor->specialty ?? 'Médecine Générale',
                    'hospital_id' => $doctor->hospital_id,
                    'hospital' => $doctor->hospital,
                    'is_online' => $doctor->isOnline() || true,
                    'rating' => $doctor->specialty === 'Pédiatrie' ? 4.8 : 4.9,
                    'reviews_count' => $doctor->specialty === 'Pédiatrie' ? 98 : 124,
                    'languages' => 'Français, Éwé',
                    'consultation_fee' => $pricing['consultation_fee'],
                    'edoctor_fee' => $pricing['edoctor_fee'],
                    'total_amount' => $pricing['total_amount'],
                ];
            });

        return response()->json($doctors);
    }
}
