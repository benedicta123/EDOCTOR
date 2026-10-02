<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\User;
use App\Services\MonetizationService;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Str;

class ConsultationController extends Controller
{
    public function index(Request $request)
    {
        Consultation::closeExpiredConsultations();

        $user = $request->user();

        $query = Consultation::where(function ($q) use ($user) {
            $q->where('patient_id', $user->id)
                ->orWhere('doctor_id', $user->id);
        })->with([
            'patient:id,name,email,phone,date_of_birth',
            'doctor:id,name,hospital_id',
            'doctor.hospital:id,name,consultation_fee',
            'prescription.items.medication',
            'payment',
        ]);

        if ($request->filled('search')) {
            $search = $request->string('search')->toString();
            $query->where(function ($q) use ($search) {
                $q->where('reference_code', 'ilike', "%{$search}%")
                    ->orWhere('diagnosis', 'ilike', "%{$search}%")
                    ->orWhereHas('patient', fn ($p) => $p->where('name', 'ilike', "%{$search}%"))
                    ->orWhereHas('doctor', fn ($d) => $d->where('name', 'ilike', "%{$search}%"));
            });
        }

        $consultations = $query->latest()->get();

        return response()->json($consultations);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'doctor_id' => ['required', 'integer', 'exists:users,id'],
            'scheduled_at' => ['nullable', 'date'],
        ]);

        $doctor = User::with('hospital')
            ->whereKey($validated['doctor_id'])
            ->where('role', 'doctor')
            ->whereHas('hospital', fn ($q) => $q->where('status', 'verifie'))
            ->firstOrFail();

        $pricing = MonetizationService::calculateConsultationPricing($doctor->hospital, $doctor);

        $consultation = Consultation::create([
            'patient_id' => $request->user()->id,
            'doctor_id' => $doctor->id,
            'scheduled_at' => $validated['scheduled_at'] ?? null,
            'status' => 'en_attente',
            'consultation_fee' => $pricing['consultation_fee'],
            'edoctor_fee' => $pricing['edoctor_fee'],
            'total_amount' => $pricing['total_amount'],
            'payment_status' => 'en_attente',
        ]);

        NotificationService::send(
            $consultation->doctor,
            'consultation_request',
            "Nouvelle demande de consultation de la part de {$request->user()->name}."
        );

        return response()->json($consultation->load(['doctor.hospital', 'patient']), 201);
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

        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:255'],
        ]);
        $reason = $validated['reason'] ?? null;

        DB::transaction(function () use ($consultation, $reason) {
            $data = ['status' => 'annulee'];
            if ($reason) {
                $data['diagnosis'] = "Refus praticien : {$reason}";
            }
            $consultation->update($data);
            if ($consultation->doctor->availability_status === 'en_consultation') {
                $consultation->doctor->update(['availability_status' => null]);
            }
        });

        $message = $reason
            ? "Le Dr {$consultation->doctor->name} a décliné la demande : {$reason}."
            : "Le Dr {$consultation->doctor->name} a décliné votre demande de consultation.";

        NotificationService::send(
            $consultation->patient,
            'consultation_declined',
            $message
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

    /**
     * POST /api/consultations/{consultation}/pay
     * Valide le règlement de la téléconsultation avec découpage financier (split).
     */
    public function pay(Request $request, Consultation $consultation)
    {
        Gate::authorize('view', $consultation);

        $validated = $request->validate([
            'payment_method' => ['required', 'in:mobile_money,carte'],
            'transaction_ref' => ['nullable', 'string'],
        ]);

        $payment = DB::transaction(function () use ($consultation, $validated) {
            $payment = $consultation->payments()->create([
                'method' => $validated['payment_method'],
                'amount' => $consultation->total_amount,
                'partner_share' => $consultation->consultation_fee,
                'edoctor_fee' => $consultation->edoctor_fee,
                'courier_share' => 0.00,
                'status' => 'confirme',
                'transaction_ref' => $validated['transaction_ref'] ?? ('TXN-CNS-' . strtoupper(Str::random(10))),
            ]);

            $consultation->update(['payment_status' => 'paye']);

            return $payment;
        });

        return response()->json([
            'message' => 'Paiement de la téléconsultation validé avec succès.',
            'consultation' => $consultation->fresh(['doctor.hospital', 'patient', 'payment']),
            'payment' => $payment,
        ]);
    }
}
