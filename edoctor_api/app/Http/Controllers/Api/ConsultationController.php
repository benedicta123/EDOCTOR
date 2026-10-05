<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Consultation;
use App\Models\Medication;
use App\Models\Pharmacy;
use App\Models\PharmacyStock;
use App\Models\User;
use App\Services\FedaPayService;
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
                ->orWhere(function ($d) use ($user) {
                    // Le médecin ne voit une demande en attente qu'une fois payée
                    $d->where('doctor_id', $user->id)->visibleToDoctor();
                });
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

        // Le médecin n'est PAS notifié ici : il le sera uniquement après confirmation
        // du paiement (voir Consultation::markAsPaid()).
        return response()->json($consultation->load(['doctor.hospital', 'patient']), 201);
    }

    public function start(Request $request, Consultation $consultation)
    {
        Gate::authorize('start', $consultation);

        abort_unless($consultation->isPaid(), 402, 'Cette consultation n\'a pas encore été payée par le patient.');

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

        // Si la demande n'a jamais été payée, le médecin n'en a jamais eu connaissance
        $shouldNotify = !($recipient?->id === $consultation->doctor_id && !$consultation->isPaid());

        if ($shouldNotify) {
            NotificationService::send(
                $recipient,
                'consultation_cancelled',
                "La consultation a été annulée par {$request->user()->name}."
            );
        }

        return response()->json($consultation);
    }

    /**
     * POST /api/consultations/{consultation}/pay
     * Valide le règlement de la téléconsultation avec découpage financier (split).
     * Uniquement disponible en mode simulation (clé FedaPay absente). Dès que FedaPay
     * est configuré, le paiement passe obligatoirement par /pay/fedapay.
     */
    public function pay(Request $request, Consultation $consultation, FedaPayService $fedapay)
    {
        Gate::authorize('view', $consultation);

        abort_if(
            $fedapay->isConfigured(),
            403,
            'Le paiement doit être effectué via FedaPay (Mobile Money).'
        );

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

            $consultation->markAsPaid();

            return $payment;
        });

        return response()->json([
            'message' => 'Paiement de la téléconsultation validé avec succès.',
            'consultation' => $consultation->fresh(['doctor.hospital', 'patient', 'payment']),
            'payment' => $payment,
        ]);
    }

    /**
     * GET /api/consultations/{consultation}/medications
     * Récupère la liste des médicaments pour la prescription du médecin.
     * Règle DG : Par défaut, filtre exclusivement sur les médicaments disponibles en stock dans les pharmacies à proximité du patient.
     * Paramètres :
     *  - in_stock_only : bool (défaut true). Si false, renvoie tout le catalogue avec badges de disponibilité.
     *  - radius_km : float (défaut 15.0 km). Rayon de recherche géographique.
     *  - q : string. Filtre de recherche par nom de molécule.
     *  - lat, lng : float. Coordonnées explicites de référence (sinon déduit de l'hôpital ou Lomé).
     */
    public function availableMedications(Request $request, Consultation $consultation)
    {
        Gate::authorize('view', $consultation);

        $inStockOnly = $request->boolean('in_stock_only', true);
        $radiusKm = (float) $request->input('radius_km', 15.0);
        $search = $request->filled('q') ? strtolower(trim($request->string('q'))) : null;

        // Détermination du point géographique de référence
        $lat = null;
        $lng = null;

        if ($request->filled('lat') && $request->filled('lng')) {
            $lat = (float) $request->input('lat');
            $lng = (float) $request->input('lng');
        } elseif ($consultation->doctor && $consultation->doctor->hospital && $consultation->doctor->hospital->latitude && $consultation->doctor->hospital->longitude) {
            $lat = (float) $consultation->doctor->hospital->latitude;
            $lng = (float) $consultation->doctor->hospital->longitude;
        } else {
            // Centre de référence par défaut (Lomé)
            $lat = 6.1375;
            $lng = 1.2125;
        }

        // Récupérer les pharmacies vérifiées avec leurs coordonnées GPS
        $pharmacies = Pharmacy::where('status', 'verifie')
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->get();

        $nearbyPharmacies = $pharmacies->map(function ($ph) use ($lat, $lng) {
            $ph->distance_km = MonetizationService::calculateDistance($lat, $lng, (float) $ph->latitude, (float) $ph->longitude);
            return $ph;
        })->filter(function ($ph) use ($radiusKm) {
            return $ph->distance_km <= $radiusKm;
        })->keyBy('id');

        $nearbyPharmacyIds = $nearbyPharmacies->keys()->all();

        // Récupérer les stocks actifs de ces pharmacies à proximité
        $stocks = PharmacyStock::whereIn('pharmacy_id', $nearbyPharmacyIds)
            ->where('quantity', '>', 0)
            ->get()
            ->groupBy('medication_id');

        // Récupérer les médicaments du catalogue
        $medQuery = Medication::query();
        if ($search) {
            $medQuery->whereRaw('LOWER(name) LIKE ?', ["%{$search}%"]);
        }
        $medications = $medQuery->orderBy('name')->get();

        // Enrichir chaque médicament avec sa disponibilité locale
        $enriched = $medications->map(function ($med) use ($stocks, $nearbyPharmacies) {
            $medStocks = $stocks->get($med->id, collect());
            $hasStock = $medStocks->isNotEmpty();
            $pharmacyCount = $medStocks->pluck('pharmacy_id')->unique()->count();

            $nearestPharmacy = null;
            $nearestDistanceKm = null;
            $minPrice = null;
            $maxPrice = null;

            if ($hasStock) {
                $minPrice = (float) $medStocks->min('price');
                $maxPrice = (float) $medStocks->max('price');

                // Trouver la pharmacie disponible la plus proche
                $availablePhIds = $medStocks->pluck('pharmacy_id')->unique()->all();
                $closest = $nearbyPharmacies->whereIn('id', $availablePhIds)->sortBy('distance_km')->first();
                if ($closest) {
                    $nearestPharmacy = $closest->name;
                    $nearestDistanceKm = round($closest->distance_km, 1);
                }
            }

            return [
                'id' => $med->id,
                'name' => $med->name,
                'category' => $med->category,
                'form' => $med->form,
                'dosage' => $med->dosage,
                'requires_prescription' => (bool) $med->requires_prescription,
                'in_stock' => $hasStock,
                'nearby_pharmacies_count' => $pharmacyCount,
                'nearest_pharmacy' => $nearestPharmacy,
                'nearest_distance_km' => $nearestDistanceKm,
                'min_price' => $minPrice,
                'max_price' => $maxPrice,
            ];
        });

        if ($inStockOnly) {
            $enriched = $enriched->filter(fn ($m) => $m['in_stock'])->values();
        } else {
            // Tri : en stock d'abord (du plus disponible au moins disponible), puis hors stock
            $enriched = $enriched->sort(function ($a, $b) {
                if ($a['in_stock'] === $b['in_stock']) {
                    return $b['nearby_pharmacies_count'] <=> $a['nearby_pharmacies_count'];
                }
                return $a['in_stock'] ? -1 : 1;
            })->values();
        }

        return response()->json([
            'reference_location' => [
                'latitude' => $lat,
                'longitude' => $lng,
                'radius_km' => $radiusKm,
            ],
            'in_stock_only' => $inStockOnly,
            'nearby_pharmacies_total' => $nearbyPharmacies->count(),
            'total_medications' => $enriched->count(),
            'medications' => $enriched,
        ]);
    }
}
