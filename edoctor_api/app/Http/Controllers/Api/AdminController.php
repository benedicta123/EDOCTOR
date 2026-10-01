<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Claim;
use App\Models\Consultation;
use App\Models\Hospital;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Pharmacy;
use App\Models\Prescription;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class AdminController extends Controller
{
    /**
     * Vérifie que l'utilisateur est un Super-Admin de la plateforme.
     */
    protected function ensureSuperAdmin(Request $request): void
    {
        $user = $request->user();
        abort_if(! $user || ! $user->isAdmin() || $user->hospital_id !== null, 403, "Accès réservé aux super-administrateurs de la plateforme eDoctor.");
    }

    /**
     * GET /api/admin/overview
     * Statistiques nationales consolidées : consultations, ordonnances, chiffre d'affaires, établissements, utilisateurs.
     */
    public function overview(Request $request)
    {
        $this->ensureSuperAdmin($request);

        // 1. Consultations
        $consultationsTotal = Consultation::count();
        $consultationsCompleted = Consultation::where('status', 'terminee')->count();
        $consultationsInProgress = Consultation::where('status', 'en_cours')->count();
        $consultationsPending = Consultation::where('status', 'en_attente')->count();
        $consultationsCancelled = Consultation::where('status', 'annulee')->count();

        // 2. Ordonnances
        $prescriptionsTotal = Prescription::count();

        // 3. Chiffre d'Affaires global & paiements
        $completedPaymentsSum = (float) Payment::where('status', 'completed')->sum('amount');
        $completedOrdersSum = (float) Order::whereIn('status', ['terminee', 'recuperee', 'en_livraison', 'prete'])->sum('total_amount');
        $totalRevenue = max($completedPaymentsSum, $completedOrdersSum);

        $paymentsByMethod = Payment::select('method', DB::raw('count(*) as count'), DB::raw('sum(amount) as total_amount'))
            ->groupBy('method')
            ->get();

        // 4. Établissements Hospitaliers
        $hospitalsTotal = Hospital::count();
        $hospitalsPending = Hospital::where('status', 'en_attente')->count();
        $hospitalsVerified = Hospital::where('status', 'verifie')->count();
        $hospitalsRejected = Hospital::where('status', 'rejete')->count();
        $hospitalsSuspended = Hospital::where('status', 'suspendu')->count();

        // 5. Pharmacies & Officines
        $pharmaciesTotal = Pharmacy::count();
        $pharmaciesPending = Pharmacy::where('status', 'en_attente')->count();
        $pharmaciesVerified = Pharmacy::where('status', 'verifie')->count();
        $pharmaciesRejected = Pharmacy::where('status', 'rejete')->count();
        $pharmaciesSuspended = Pharmacy::where('status', 'suspendu')->count();

        // 6. Utilisateurs & Soignants
        $usersTotal = User::count();
        $patientsCount = User::where('role', 'patient')->count();
        $doctorsCount = User::where('role', 'doctor')->count();
        $pharmacistsCount = User::where('role', 'pharmacist')->count();
        $nursesCount = User::where('role', 'nurse')->count();
        $adminsCount = User::where('role', 'admin')->count();
        $suspendedUsersCount = User::where('is_suspended', true)->count();

        // 7. Réclamations & Litiges
        $claimsTotal = Claim::count();
        $claimsOpen = Claim::where('status', 'ouvert')->count();
        $claimsInProgress = Claim::where('status', 'en_cours')->count();
        $claimsResolved = Claim::where('status', 'resolu')->count();

        // 8. Événements récents pour le flux en temps réel
        $recentConsultations = Consultation::with(['patient:id,name,phone', 'doctor:id,name,specialty'])
            ->latest()
            ->take(5)
            ->get();

        $recentHospitalsPending = Hospital::where('status', 'en_attente')
            ->latest()
            ->take(5)
            ->get();

        $recentPharmaciesPending = Pharmacy::where('status', 'en_attente')
            ->with('owner:id,name,email,phone')
            ->latest()
            ->take(5)
            ->get();

        return response()->json([
            'metrics' => [
                'consultations' => [
                    'total' => $consultationsTotal,
                    'completed' => $consultationsCompleted,
                    'in_progress' => $consultationsInProgress,
                    'pending' => $consultationsPending,
                    'cancelled' => $consultationsCancelled,
                ],
                'prescriptions' => [
                    'total' => $prescriptionsTotal,
                ],
                'revenue' => [
                    'total_fcfa' => $totalRevenue,
                    'payments_sum' => $completedPaymentsSum,
                    'orders_sum' => $completedOrdersSum,
                    'by_method' => $paymentsByMethod,
                ],
                'hospitals' => [
                    'total' => $hospitalsTotal,
                    'pending' => $hospitalsPending,
                    'verified' => $hospitalsVerified,
                    'rejected' => $hospitalsRejected,
                    'suspended' => $hospitalsSuspended,
                ],
                'pharmacies' => [
                    'total' => $pharmaciesTotal,
                    'pending' => $pharmaciesPending,
                    'verified' => $pharmaciesVerified,
                    'rejected' => $pharmaciesRejected,
                    'suspended' => $pharmaciesSuspended,
                ],
                'users' => [
                    'total' => $usersTotal,
                    'patients' => $patientsCount,
                    'doctors' => $doctorsCount,
                    'pharmacists' => $pharmacistsCount,
                    'nurses' => $nursesCount,
                    'admins' => $adminsCount,
                    'suspended' => $suspendedUsersCount,
                ],
                'claims' => [
                    'total' => $claimsTotal,
                    'open' => $claimsOpen,
                    'in_progress' => $claimsInProgress,
                    'resolved' => $claimsResolved,
                ],
            ],
            'recent' => [
                'consultations' => $recentConsultations,
                'pending_hospitals' => $recentHospitalsPending,
                'pending_pharmacies' => $recentPharmaciesPending,
            ],
        ]);
    }

    // ==========================================
    // MODULE HÔPITAUX PARTENAIRES & HOMOLOGATION
    // ==========================================

    /**
     * GET /api/admin/hospitals
     */
    public function hospitals(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $query = Hospital::withCount(['doctors', 'staff'])
            ->with('admins:id,name,email,phone,hospital_id');

        if ($request->filled('status') && $request->status !== 'tous') {
            $query->where('status', $request->status);
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('address', 'like', "%{$search}%")
                    ->orWhere('license_number', 'like', "%{$search}%")
                    ->orWhere('official_email', 'like', "%{$search}%")
                    ->orWhere('tax_number', 'like', "%{$search}%");
            });
        }

        $hospitals = $query->latest()->get();

        return response()->json($hospitals);
    }

    /**
     * POST /api/admin/hospitals/{hospital}/verify
     */
    public function verifyHospital(Request $request, Hospital $hospital)
    {
        $this->ensureSuperAdmin($request);

        $hospital->update([
            'status' => 'verifie',
            'verified_at' => now(),
            'rejected_reason' => null,
        ]);

        foreach ($hospital->admins as $admin) {
            NotificationService::send(
                $admin,
                'hospital_verified',
                "Félicitations ! L'homologation de {$hospital->name} a été validée par la Régulation eDoctor."
            );
        }

        return response()->json([
            'message' => "L'établissement {$hospital->name} a été homologué avec succès.",
            'hospital' => $hospital->fresh(),
        ]);
    }

    /**
     * POST /api/admin/hospitals/{hospital}/reject
     */
    public function rejectHospital(Request $request, Hospital $hospital)
    {
        $this->ensureSuperAdmin($request);

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        $hospital->update([
            'status' => 'rejete',
            'rejected_reason' => $validated['reason'],
        ]);

        foreach ($hospital->admins as $admin) {
            NotificationService::send(
                $admin,
                'hospital_rejected',
                "Le dossier d'homologation pour {$hospital->name} a été rejeté : {$validated['reason']}"
            );
        }

        return response()->json([
            'message' => "L'établissement {$hospital->name} a été rejeté.",
            'hospital' => $hospital->fresh(),
        ]);
    }

    /**
     * POST /api/admin/hospitals/{hospital}/suspend
     */
    public function suspendHospital(Request $request, Hospital $hospital)
    {
        $this->ensureSuperAdmin($request);

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        $hospital->update([
            'status' => 'suspendu',
            'rejected_reason' => $validated['reason'],
        ]);

        foreach ($hospital->admins as $admin) {
            NotificationService::send(
                $admin,
                'hospital_suspended',
                "Alerte réglementaire : Les activités de {$hospital->name} ont été suspendues : {$validated['reason']}"
            );
        }

        return response()->json([
            'message' => "L'établissement {$hospital->name} a été suspendu.",
            'hospital' => $hospital->fresh(),
        ]);
    }

    /**
     * POST /api/admin/hospitals/{hospital}/reactivate
     */
    public function reactivateHospital(Request $request, Hospital $hospital)
    {
        $this->ensureSuperAdmin($request);

        $hospital->update([
            'status' => 'verifie',
            'rejected_reason' => null,
        ]);

        return response()->json([
            'message' => "L'établissement {$hospital->name} a été réactivé avec succès.",
            'hospital' => $hospital->fresh(),
        ]);
    }

    // ==========================================
    // MODULE PHARMACIES & LICENCE D'OFFICINE
    // ==========================================

    /**
     * GET /api/admin/pharmacies
     */
    public function pharmacies(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $query = Pharmacy::with(['owner:id,name,email,phone,license_number', 'stocks']);

        if ($request->filled('status') && $request->status !== 'tous') {
            $query->where('status', $request->status);
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('address', 'like', "%{$search}%")
                    ->orWhere('reference_id', 'like', "%{$search}%")
                    ->orWhere('license_number', 'like', "%{$search}%")
                    ->orWhere('order_number', 'like', "%{$search}%")
                    ->orWhere('official_email', 'like', "%{$search}%");
            });
        }

        $pharmacies = $query->latest()->get();

        return response()->json($pharmacies);
    }

    /**
     * POST /api/admin/pharmacies/{pharmacy}/verify
     */
    public function verifyPharmacy(Request $request, Pharmacy $pharmacy)
    {
        $this->ensureSuperAdmin($request);

        $pharmacy->update([
            'status' => 'verifie',
            'verified_at' => now(),
            'rejected_reason' => null,
        ]);

        if ($pharmacy->owner) {
            NotificationService::send(
                $pharmacy->owner,
                'pharmacy_verified',
                "Félicitations ! L'officine {$pharmacy->name} est officiellement homologuée sur la plateforme eDoctor."
            );
        }

        return response()->json([
            'message' => "L'officine {$pharmacy->name} a été validée avec succès.",
            'pharmacy' => $pharmacy->fresh(['owner']),
        ]);
    }

    /**
     * POST /api/admin/pharmacies/{pharmacy}/reject
     */
    public function rejectPharmacy(Request $request, Pharmacy $pharmacy)
    {
        $this->ensureSuperAdmin($request);

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        $pharmacy->update([
            'status' => 'rejete',
            'rejected_reason' => $validated['reason'],
        ]);

        if ($pharmacy->owner) {
            NotificationService::send(
                $pharmacy->owner,
                'pharmacy_rejected',
                "Votre demande d'agrément pour {$pharmacy->name} a été rejetée : {$validated['reason']}"
            );
        }

        return response()->json([
            'message' => "L'officine {$pharmacy->name} a été rejetée.",
            'pharmacy' => $pharmacy->fresh(['owner']),
        ]);
    }

    /**
     * POST /api/admin/pharmacies/{pharmacy}/suspend
     */
    public function suspendPharmacy(Request $request, Pharmacy $pharmacy)
    {
        $this->ensureSuperAdmin($request);

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        $pharmacy->update([
            'status' => 'suspendu',
            'rejected_reason' => $validated['reason'],
        ]);

        if ($pharmacy->owner) {
            NotificationService::send(
                $pharmacy->owner,
                'pharmacy_suspended',
                "Alerte réglementaire : Votre officine {$pharmacy->name} a été suspendue : {$validated['reason']}"
            );
        }

        return response()->json([
            'message' => "L'officine {$pharmacy->name} a été suspendue.",
            'pharmacy' => $pharmacy->fresh(['owner']),
        ]);
    }

    /**
     * POST /api/admin/pharmacies/{pharmacy}/reactivate
     */
    public function reactivatePharmacy(Request $request, Pharmacy $pharmacy)
    {
        $this->ensureSuperAdmin($request);

        $pharmacy->update([
            'status' => 'verifie',
            'rejected_reason' => null,
        ]);

        return response()->json([
            'message' => "L'officine {$pharmacy->name} a été réactivée avec succès.",
            'pharmacy' => $pharmacy->fresh(['owner']),
        ]);
    }

    // ==========================================
    // MODULE GESTION DES UTILISATEURS & MODÉRATION
    // ==========================================

    /**
     * GET /api/admin/users
     */
    public function users(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $query = User::with(['hospital:id,name', 'pharmacy:id,name,owner_id']);

        if ($request->filled('role') && $request->role !== 'tous') {
            $query->where('role', $request->role);
        }

        if ($request->filled('status')) {
            if ($request->status === 'suspendu') {
                $query->where('is_suspended', true);
            } elseif ($request->status === 'actif') {
                $query->where('is_suspended', false);
            }
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('license_number', 'like', "%{$search}%");
            });
        }

        $users = $query->latest()->paginate($request->input('per_page', 50));

        return response()->json($users);
    }

    /**
     * POST /api/admin/users/{user}/suspend
     */
    public function suspendUser(Request $request, User $user)
    {
        $this->ensureSuperAdmin($request);

        if ($user->id === $request->user()->id) {
            return response()->json([
                'message' => "Vous ne pouvez pas suspendre votre propre compte super-administrateur.",
            ], 422);
        }

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        $user->update([
            'is_suspended' => true,
            'suspension_reason' => $validated['reason'],
            'suspended_at' => now(),
        ]);

        // Révocation de tous les jetons actifs
        $user->tokens()->delete();

        NotificationService::send(
            $user,
            'account_suspended',
            "Votre compte eDoctor a été suspendu pour le motif suivant : {$validated['reason']}"
        );

        return response()->json([
            'message' => "Le compte de {$user->name} a été suspendu.",
            'user' => $user->fresh(),
        ]);
    }

    /**
     * POST /api/admin/users/{user}/reactivate
     */
    public function reactivateUser(Request $request, User $user)
    {
        $this->ensureSuperAdmin($request);

        $user->update([
            'is_suspended' => false,
            'suspension_reason' => null,
            'suspended_at' => null,
        ]);

        NotificationService::send(
            $user,
            'account_reactivated',
            "Votre compte eDoctor a été réactivé. Vous pouvez de nouveau vous connecter."
        );

        return response()->json([
            'message' => "Le compte de {$user->name} a été réactivé avec succès.",
            'user' => $user->fresh(),
        ]);
    }

    // ==========================================
    // MODULE JOURNAL DES RÉCLAMATIONS & LITIGES
    // ==========================================

    /**
     * GET /api/admin/claims
     */
    public function claims(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $query = Claim::with(['user:id,name,email,phone,role', 'resolver:id,name']);

        if ($request->filled('status') && $request->status !== 'tous') {
            $query->where('status', $request->status);
        }

        if ($request->filled('priority') && $request->priority !== 'tous') {
            $query->where('priority', $request->priority);
        }

        if ($request->filled('category') && $request->category !== 'tous') {
            $query->where('category', $request->category);
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('reference_id', 'like', "%{$search}%")
                    ->orWhere('subject', 'like', "%{$search}%")
                    ->orWhere('description', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uq) use ($search) {
                        $uq->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%");
                    });
            });
        }

        $claims = $query->latest()->get();

        return response()->json($claims);
    }

    /**
     * POST /api/admin/claims
     * Création d'une réclamation (par un patient, médecin ou admin).
     */
    public function storeClaim(Request $request)
    {
        $validated = $request->validate([
            'subject' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'category' => ['required', 'string', 'max:60'],
            'priority' => ['nullable', 'string', 'in:faible,normale,haute,urgente'],
            'target_type' => ['nullable', 'string', 'max:50'],
            'target_id' => ['nullable', 'integer'],
        ]);

        $referenceId = 'REC-2026-' . strtoupper(Str::random(5));

        $claim = Claim::create([
            'reference_id' => $referenceId,
            'user_id' => $request->user()->id,
            'target_type' => $validated['target_type'] ?? 'platform',
            'target_id' => $validated['target_id'] ?? null,
            'category' => $validated['category'],
            'priority' => $validated['priority'] ?? 'normale',
            'subject' => $validated['subject'],
            'description' => $validated['description'],
            'status' => 'ouvert',
        ]);

        return response()->json([
            'message' => 'Réclamation enregistrée avec succès.',
            'claim' => $claim->load('user:id,name,email,role'),
        ], 201);
    }

    /**
     * POST /api/admin/claims/{claim}/resolve
     */
    public function resolveClaim(Request $request, Claim $claim)
    {
        $this->ensureSuperAdmin($request);

        $validated = $request->validate([
            'notes' => ['required', 'string', 'max:2000'],
        ]);

        $claim->update([
            'status' => 'resolu',
            'resolution_notes' => $validated['notes'],
            'resolved_by' => $request->user()->id,
            'resolved_at' => now(),
        ]);

        if ($claim->user) {
            NotificationService::send(
                $claim->user,
                'claim_resolved',
                "Votre réclamation {$claim->reference_id} a été traitée et résolue par nos services : {$validated['notes']}"
            );
        }

        return response()->json([
            'message' => "La réclamation {$claim->reference_id} a été marquée comme résolue.",
            'claim' => $claim->fresh(['user', 'resolver']),
        ]);
    }

    /**
     * POST /api/admin/claims/{claim}/status
     */
    public function updateClaimStatus(Request $request, Claim $claim)
    {
        $this->ensureSuperAdmin($request);

        $validated = $request->validate([
            'status' => ['required', 'string', 'in:ouvert,en_cours,resolu,rejete'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);

        $data = ['status' => $validated['status']];
        if (! empty($validated['notes'])) {
            $data['resolution_notes'] = $validated['notes'];
        }
        if ($validated['status'] === 'resolu') {
            $data['resolved_by'] = $request->user()->id;
            $data['resolved_at'] = now();
        }

        $claim->update($data);

        return response()->json([
            'message' => "Statut de la réclamation {$claim->reference_id} mis à jour.",
            'claim' => $claim->fresh(['user', 'resolver']),
        ]);
    }
}
