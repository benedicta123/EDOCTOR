<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hospital;
use App\Models\HospitalAppointment;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class HospitalAppointmentController extends Controller
{
    /**
     * Services par défaut proposés dans les cliniques et hôpitaux
     */
    public const DEPARTMENTS = [
        'Médecine Générale',
        'Pédiatrie',
        'Gynécologie & Obstétrique',
        'Cardiologie',
        'Ophtalmologie',
        'Dermatologie',
        'Stomatologie & Dentaire',
        'Chirurgie Générale',
        'ORL',
    ];

    /**
     * Créneaux horaires standards par tranche de 30 min
     */
    public const DEFAULT_TIME_SLOTS = [
        '08:00 - 08:30',
        '08:30 - 09:00',
        '09:00 - 09:30',
        '09:30 - 10:00',
        '10:00 - 10:30',
        '10:30 - 11:00',
        '11:00 - 11:30',
        '11:30 - 12:00',
        '14:30 - 15:00',
        '15:00 - 15:30',
        '15:30 - 16:00',
        '16:00 - 16:30',
        '16:30 - 17:00',
    ];

    /**
     * GET /api/hospitals
     * Retourne la liste des hôpitaux vérifiés disponibles pour la réservation de créneaux.
     */
    public function hospitals(): JsonResponse
    {
        $hospitals = Hospital::verified()
            ->select('id', 'name', 'address', 'phone', 'consultation_fee')
            ->orderBy('name')
            ->get();

        return response()->json([
            'hospitals' => $hospitals,
        ]);
    }

    /**
     * GET /api/hospitals/{hospital}/slots
     * Retourne les services, praticiens et créneaux avec disponibilité pour une date donnée.
     */
    public function getSlots(Request $request, Hospital $hospital): JsonResponse
    {
        $date = $request->query('date', now()->toDateString());
        $department = $request->query('department');

        // Récupérer les réservations existantes pour cette date
        $bookedSlotsQuery = HospitalAppointment::where('hospital_id', $hospital->id)
            ->whereDate('appointment_date', $date)
            ->whereNotIn('status', ['annule']);

        if ($department) {
            $bookedSlotsQuery->where('department', $department);
        }

        $bookedCounts = $bookedSlotsQuery
            ->select('time_slot', DB::raw('count(*) as count'))
            ->groupBy('time_slot')
            ->pluck('count', 'time_slot')
            ->toArray();

        // Médecins affiliés à l'hôpital
        $doctors = $hospital->doctors()
            ->where('is_suspended', false)
            ->select('id', 'name', 'specialty', 'phone')
            ->get();

        $slots = [];
        $maxPerSlot = 3; // Capacité max par créneau pour éviter les surcharges

        foreach (self::DEFAULT_TIME_SLOTS as $slot) {
            $booked = $bookedCounts[$slot] ?? 0;
            $slots[] = [
                'time_slot' => $slot,
                'booked_count' => $booked,
                'available' => $booked < $maxPerSlot,
                'remaining' => max(0, $maxPerSlot - $booked),
            ];
        }

        return response()->json([
            'hospital' => [
                'id' => $hospital->id,
                'name' => $hospital->name,
                'address' => $hospital->address,
                'phone' => $hospital->phone,
                'consultation_fee' => (float) ($hospital->consultation_fee ?? 3000),
            ],
            'departments' => self::DEPARTMENTS,
            'doctors' => $doctors,
            'date' => $date,
            'slots' => $slots,
        ]);
    }

    /**
     * POST /api/hospital-appointments
     * Réservation d'un créneau par le patient
     */
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'hospital_id' => ['required', 'exists:hospitals,id'],
            'department' => ['required', 'string', 'max:100'],
            'appointment_date' => ['required', 'date', 'after_or_equal:today'],
            'time_slot' => ['required', 'string', 'max:50'],
            'doctor_id' => ['nullable', 'exists:users,id'],
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        $hospital = Hospital::findOrFail($validated['hospital_id']);

        // Vérifier si le patient a déjà un RDV pour ce même créneau
        $existing = HospitalAppointment::where('patient_id', $user->id)
            ->where('hospital_id', $hospital->id)
            ->whereDate('appointment_date', $validated['appointment_date'])
            ->where('time_slot', $validated['time_slot'])
            ->whereNotIn('status', ['annule'])
            ->first();

        if ($existing) {
            return response()->json([
                'message' => 'Vous avez déjà une réservation sur ce créneau horaire.',
                'appointment' => $existing->load(['hospital', 'doctor']),
            ], 422);
        }

        $appointment = DB::transaction(function () use ($validated, $hospital, $user) {
            $ref = HospitalAppointment::generateReferenceCode($hospital);
            $queueNum = HospitalAppointment::nextQueueNumber($hospital->id, $validated['appointment_date']);

            return HospitalAppointment::create([
                'reference_code' => $ref,
                'hospital_id' => $hospital->id,
                'patient_id' => $user->id,
                'doctor_id' => $validated['doctor_id'] ?? null,
                'department' => $validated['department'],
                'appointment_date' => $validated['appointment_date'],
                'time_slot' => $validated['time_slot'],
                'queue_number' => $queueNum,
                'reason' => $validated['reason'] ?? null,
                'status' => 'reserve',
                'consultation_fee' => $hospital->consultation_fee ?? 3000,
            ]);
        });

        // Alerte envoyée à l'hôpital
        foreach ($hospital->admins as $admin) {
            NotificationService::send(
                $admin,
                'hospital_appointment_booked',
                "Nouveau RDV sur place ({$appointment->reference_code}) : {$user->name} au service {$appointment->department} le {$appointment->appointment_date->format('d/m/Y')} ({$appointment->time_slot})."
            );
        }

        // Si un médecin spécifique a été choisi par le patient
        if ($appointment->doctor_id) {
            $doctor = User::find($appointment->doctor_id);
            if ($doctor) {
                NotificationService::send(
                    $doctor,
                    'hospital_appointment_doctor_booked',
                    "Le patient {$user->name} a réservé un créneau physique avec vous le {$appointment->appointment_date->format('d/m/Y')} ({$appointment->time_slot}) au service {$appointment->department}."
                );
            }
        }

        return response()->json([
            'message' => 'Votre créneau de consultation a été réservé avec succès.',
            'appointment' => $appointment->fresh(['hospital', 'doctor', 'patient']),
        ], 201);
    }

    /**
     * GET /api/my-hospital-appointments
     * Liste des réservations de l'utilisateur connecté (patient)
     */
    public function myAppointments(Request $request): JsonResponse
    {
        $user = $request->user();

        $appointments = HospitalAppointment::with(['hospital', 'doctor:id,name,specialty,phone'])
            ->where('patient_id', $user->id)
            ->orderBy('appointment_date', 'desc')
            ->orderBy('id', 'desc')
            ->get();

        return response()->json([
            'appointments' => $appointments,
        ]);
    }

    /**
     * GET /api/hospital-appointments/queue
     * File d'attente et registre des consultations présentielles pour le personnel hospitalier
     */
    public function queue(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isHospitalAdmin() && ! $user->isDoctor() && ! $user->isAdmin()) {
            abort(403, 'Accès réservé au personnel hospitalier.');
        }

        $hospitalId = $user->hospital_id ?? $request->query('hospital_id');
        if (! $hospitalId) {
            return response()->json(['appointments' => [], 'summary' => []]);
        }

        $date = $request->query('date', now()->toDateString());
        $department = $request->query('department');
        $status = $request->query('status'); // 'reserve', 'en_attente', 'en_consultation', 'termine'

        $query = HospitalAppointment::with([
            'patient:id,name,phone,email,birth_date,blood_group',
            'doctor:id,name,specialty',
            'assignedBy:id,name',
        ])
            ->where('hospital_id', $hospitalId)
            ->whereDate('appointment_date', $date);

        // Si le praticien est un médecin, il peut filtrer sur ses consultations ou voir tout le service
        if ($user->isDoctor() && $request->boolean('only_mine', false)) {
            $query->where('doctor_id', $user->id);
        }

        if ($department) {
            $query->where('department', $department);
        }

        if ($status) {
            $query->where('status', $status);
        }

        $appointments = $query
            ->orderByRaw("CASE 
                WHEN status = 'en_consultation' THEN 1
                WHEN status = 'en_attente' THEN 2
                WHEN status = 'reserve' THEN 3
                WHEN status = 'termine' THEN 4
                ELSE 5 END")
            ->orderBy('queue_number', 'asc')
            ->get();

        // Statistiques du jour
        $summary = [
            'total_today' => HospitalAppointment::where('hospital_id', $hospitalId)->whereDate('appointment_date', $date)->count(),
            'booked' => HospitalAppointment::where('hospital_id', $hospitalId)->whereDate('appointment_date', $date)->where('status', 'reserve')->count(),
            'waiting_room' => HospitalAppointment::where('hospital_id', $hospitalId)->whereDate('appointment_date', $date)->where('status', 'en_attente')->count(),
            'in_consultation' => HospitalAppointment::where('hospital_id', $hospitalId)->whereDate('appointment_date', $date)->where('status', 'en_consultation')->count(),
            'completed' => HospitalAppointment::where('hospital_id', $hospitalId)->whereDate('appointment_date', $date)->where('status', 'termine')->count(),
        ];

        // Liste des médecins actuellement en service dans l'établissement
        $doctors = User::where('hospital_id', $hospitalId)
            ->where('role', 'doctor')
            ->select('id', 'name', 'specialty')
            ->get();

        return response()->json([
            'date' => $date,
            'summary' => $summary,
            'doctors' => $doctors,
            'appointments' => $appointments,
        ]);
    }

    /**
     * POST /api/hospital-appointments/{appointment}/check-in
     * Accueil / Réception : valide l'arrivée du patient et l'affecte au médecin
     */
    public function checkIn(Request $request, HospitalAppointment $appointment): JsonResponse
    {
        $user = $request->user();

        if (! $user->isHospitalAdmin() && ! $user->isDoctor() && ! $user->isAdmin()) {
            abort(403, 'Action non autorisée.');
        }

        $validated = $request->validate([
            'doctor_id' => ['nullable', 'exists:users,id'],
        ]);

        $doctorId = $validated['doctor_id'] ?? $appointment->doctor_id;

        $appointment->update([
            'status' => 'en_attente', // En salle d'attente
            'checked_in_at' => now(),
            'doctor_id' => $doctorId,
            'assigned_by' => $user->id,
        ]);

        // Si un médecin est assigné, l'alerter qu'un patient l'attend
        if ($doctorId) {
            $doctor = User::find($doctorId);
            if ($doctor) {
                NotificationService::send(
                    $doctor,
                    'patient_in_waiting_room',
                    "Le patient {$appointment->patient->name} est arrivé (N° passage #{$appointment->queue_number}) et vous attend en salle d'attente."
                );
            }
        }

        // Notification de confirmation au patient
        NotificationService::send(
            $appointment->patient,
            'hospital_checkin_confirmed',
            "Votre arrivée a été enregistrée à {$appointment->hospital->name}. N° de passage : #{$appointment->queue_number}. Vous serez bientôt appelé(e)."
        );

        return response()->json([
            'message' => 'Arrivée du patient validée. Patient placé en salle d’attente.',
            'appointment' => $appointment->fresh(['hospital', 'doctor', 'patient', 'assignedBy']),
        ]);
    }

    /**
     * POST /api/hospital-appointments/{appointment}/call-in
     * Le médecin appelle le patient dans son bureau de consultation
     */
    public function callIn(Request $request, HospitalAppointment $appointment): JsonResponse
    {
        $user = $request->user();

        if (! $user->isDoctor() && ! $user->isHospitalAdmin() && ! $user->isAdmin()) {
            abort(403, 'Action réservée aux praticiens.');
        }

        $appointment->update([
            'status' => 'en_consultation',
            'called_at' => now(),
            'doctor_id' => $user->isDoctor() ? $user->id : ($appointment->doctor_id ?? $user->id),
        ]);

        // Alerte push au patient pour entrer
        NotificationService::send(
            $appointment->patient,
            'hospital_patient_called',
            "Le Dr {$appointment->doctor?->name} vous invite à entrer dans son cabinet de consultation."
        );

        return response()->json([
            'message' => 'Patient appelé en consultation.',
            'appointment' => $appointment->fresh(['hospital', 'doctor', 'patient']),
        ]);
    }

    /**
     * POST /api/hospital-appointments/{appointment}/complete
     * Clôture de la consultation par le praticien
     */
    public function complete(Request $request, HospitalAppointment $appointment): JsonResponse
    {
        $user = $request->user();

        if (! $user->isDoctor() && ! $user->isHospitalAdmin() && ! $user->isAdmin()) {
            abort(403, 'Action réservée aux praticiens.');
        }

        $validated = $request->validate([
            'doctor_notes' => ['nullable', 'string', 'max:3000'],
        ]);

        $appointment->update([
            'status' => 'termine',
            'completed_at' => now(),
            'doctor_notes' => $validated['doctor_notes'] ?? $appointment->doctor_notes,
        ]);

        NotificationService::send(
            $appointment->patient,
            'hospital_appointment_completed',
            "Votre consultation du {$appointment->appointment_date->format('d/m/Y')} à {$appointment->hospital->name} a été clôturée. Merci pour votre confiance."
        );

        return response()->json([
            'message' => 'Consultation physique terminée et archivée.',
            'appointment' => $appointment->fresh(['hospital', 'doctor', 'patient']),
        ]);
    }

    /**
     * POST /api/hospital-appointments/{appointment}/cancel
     * Annulation du rendez-vous
     */
    public function cancel(Request $request, HospitalAppointment $appointment): JsonResponse
    {
        $user = $request->user();

        if ($user->id !== $appointment->patient_id && ! $user->isHospitalAdmin() && ! $user->isAdmin()) {
            abort(403, 'Non autorisé à annuler ce rendez-vous.');
        }

        $appointment->update([
            'status' => 'annule',
            'cancelled_at' => now(),
        ]);

        return response()->json([
            'message' => 'Le rendez-vous a été annulé.',
            'appointment' => $appointment->fresh(['hospital', 'doctor', 'patient']),
        ]);
    }
}
