<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use App\Models\Traits\HasSafeUtf8Attributes;
use App\Services\NotificationService;

class Consultation extends Model
{
    use HasFactory, HasSafeUtf8Attributes;

    protected $fillable = [
        'reference_code', 'patient_id', 'doctor_id', 'status', 'scheduled_at', 'started_at', 'ended_at',
        'diagnosis', 'consultation_fee', 'edoctor_fee', 'total_amount', 'payment_status',
    ];

    protected static function booted(): void
    {
        static::creating(function (Consultation $consultation) {
            if (empty($consultation->reference_code)) {
                $consultation->reference_code = static::generateReferenceCode(
                    $consultation->doctor_id,
                    $consultation->created_at ?? now()
                );
            }
        });
    }

    /**
     * Génère un code de référence structuré et unique : CNS-[AAMM]-[HOPITAL]-[4CHARS]
     * Ex: CNS-2609-CHU-4F7B
     */
    public static function generateReferenceCode(?int $doctorId = null, ?\DateTimeInterface $date = null): string
    {
        $dt = $date ? \Carbon\Carbon::parse($date) : now();
        $yearMonth = $dt->format('ym');
        $hospitalCode = 'EDO';

        if ($doctorId) {
            $doctor = User::with('hospital')->find($doctorId);
            if ($doctor && $doctor->hospital) {
                $hospitalCode = static::extractHospitalCode($doctor->hospital->name);
            }
        }

        $chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
        $charLen = strlen($chars);

        do {
            $suffix = '';
            for ($i = 0; $i < 4; $i++) {
                $suffix .= $chars[random_int(0, $charLen - 1)];
            }
            $code = "CNS-{$yearMonth}-{$hospitalCode}-{$suffix}";
        } while (static::where('reference_code', $code)->exists());

        return $code;
    }

    /**
     * Extrait un trigramme significatif (3 à 4 lettres) depuis le nom de l'hôpital.
     * Ex : "Centre Hospitalier Universitaire" -> "CHU"
     */
    public static function extractHospitalCode(string $name): string
    {
        $asciiName = Str::ascii($name);
        $words = preg_split('/[\s,\-\']+/u', trim($asciiName));
        $stopWords = ['de', 'du', 'la', 'le', 'les', 'des', 'et', 'd', 'l', 'au', 'aux'];
        $filtered = [];

        foreach ($words as $w) {
            $clean = preg_replace('/[^a-zA-Z0-9]/', '', $w);
            if (strlen($clean) > 0 && !in_array(strtolower($clean), $stopWords)) {
                $filtered[] = $clean;
            }
        }

        $initials = '';
        foreach ($filtered as $w) {
            $initials .= substr($w, 0, 1);
            if (strlen($initials) >= 4) {
                break;
            }
        }

        if (strlen($initials) >= 2) {
            return strtoupper(substr($initials, 0, 4));
        }

        $cleanAll = preg_replace('/[^a-zA-Z0-9]/', '', $asciiName);
        return strtoupper(substr($cleanAll, 0, 3)) ?: 'EDO';
    }

    /**
     * Nettoyage automatique des caractères non-UTF8 pour éviter les erreurs de sérialisation JSON.
     */
    protected function referenceCode(): Attribute
    {
        return Attribute::make(
            get: fn ($v) => $v ? mb_convert_encoding($v, 'UTF-8', 'UTF-8') : null,
            set: fn ($v) => $v ? mb_convert_encoding($v, 'UTF-8', 'UTF-8') : null,
        );
    }

    protected $casts = [
        'scheduled_at' => 'datetime',
        'started_at' => 'datetime',
        'ended_at' => 'datetime',
        'consultation_fee' => 'decimal:2',
        'edoctor_fee' => 'decimal:2',
        'total_amount' => 'decimal:2',
    ];

    /**
     * Chiffrement sécurisé du diagnostic avec tolérance aux anciennes données en clair.
     */
    protected function diagnosis(): Attribute
    {
        return Attribute::make(
            get: function ($value) {
                if ($value === null || $value === '') {
                    return $value;
                }
                try {
                    $decrypted = Crypt::decryptString($value);
                    return mb_convert_encoding($decrypted, 'UTF-8', 'UTF-8');
                } catch (\Throwable) {
                    return mb_convert_encoding($value, 'UTF-8', 'UTF-8');
                }
            },
            set: function ($value) {
                if ($value === null || $value === '') {
                    return $value;
                }
                try {
                    return Crypt::encryptString($value);
                } catch (\Throwable) {
                    return mb_convert_encoding($value, 'UTF-8', 'UTF-8');
                }
            }
        );
    }

    public function patient(): BelongsTo
    {
        return $this->belongsTo(User::class, 'patient_id');
    }

    public function doctor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'doctor_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }

    public function prescription(): HasOne
    {
        return $this->hasOne(Prescription::class);
    }

    public function labRequests(): HasMany
    {
        return $this->hasMany(LabRequest::class);
    }

    public function payment(): HasOne
    {
        return $this->hasOne(Payment::class)->latestOfMany();
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public function isParticipant(User $user): bool
    {
        return $user->id === $this->patient_id || $user->id === $this->doctor_id;
    }

    /**
     * Une demande n'est visible par le médecin (et ne déclenche la sonnerie)
     * qu'une fois le paiement du patient confirmé (ou si elle est en cours/terminée).
     * Les demandes abandonnées ou annulées sans avoir été payées ne polluent jamais l'espace du praticien.
     */
    public function scopeVisibleToDoctor($query)
    {
        return $query->where(function ($q) {
            $q->where('payment_status', 'paye')
                ->orWhereIn('status', ['en_cours', 'terminee']);
        });
    }

    public function isPaid(): bool
    {
        return $this->payment_status === 'paye';
    }

    /**
     * Marque la consultation comme payée et prévient le médecin (une seule fois).
     */
    public function markAsPaid(): void
    {
        if ($this->isPaid()) {
            return;
        }

        $this->update(['payment_status' => 'paye']);

        // Séquestre automatique des honoraires dans le portefeuille hospitalier / médical
        $beneficiary = $this->doctor?->hospital ?? $this->doctor;
        if ($beneficiary) {
            $wallet = $beneficiary->getOrCreateWallet();
            $fee = (float) $this->consultation_fee;
            if ($fee > 0) {
                $wallet->hold(
                    $fee,
                    "Honoraires sous séquestre pour téléconsultation #{$this->id}",
                    'consultation',
                    $this->id
                );
            }
        }

        if ($this->status === 'en_attente' && $this->doctor) {
            NotificationService::send(
                $this->doctor,
                'consultation_request',
                'Nouvelle demande de consultation (payée) de la part de ' . ($this->patient?->name ?? 'un patient') . '.'
            );
        }
    }

    /**
     * Clôture automatiquement les téléconsultations en cours depuis plus de 2 heures (120 minutes)
     * et annule les consultations payées restées sans réponse du praticien après 20 minutes.
     */
    public static function closeExpiredConsultations(): int
    {
        $count = static::cancelUnansweredConsultations();

        $cutoff = now()->subHours(2);

        $expired = static::where('status', 'en_cours')
            ->whereNotNull('started_at')
            ->where('started_at', '<=', $cutoff)
            ->with(['doctor', 'patient'])
            ->get();

        foreach ($expired as $consultation) {
            DB::transaction(function () use ($consultation) {
                $consultation->update([
                    'status' => 'terminee',
                    'ended_at' => now(),
                    'diagnosis' => $consultation->diagnosis
                        ? $consultation->diagnosis . "\n[Clôture automatique du système : durée maximale de 2 heures atteinte]"
                        : "[Clôture automatique du système : durée maximale de 2 heures atteinte]",
                ]);

                if ($consultation->doctor && $consultation->doctor->availability_status === 'en_consultation') {
                    $consultation->doctor->update(['availability_status' => null]);
                }
            });

            // Notification patient
            if ($consultation->patient) {
                NotificationService::send(
                    $consultation->patient,
                    'consultation_ended',
                    "Votre téléconsultation avec le Dr {$consultation->doctor?->name} a été coupée automatiquement par le système (durée maximale de 2h atteinte)."
                );
            }

            // Notification médecin
            if ($consultation->doctor) {
                NotificationService::send(
                    $consultation->doctor,
                    'consultation_ended',
                    "La téléconsultation avec {$consultation->patient?->name} a été coupée automatiquement par le système (durée maximale de 2h atteinte)."
                );
            }

            $count++;
        }

        return $count;
    }

    /**
     * Annule automatiquement les demandes payées non prises en charge par le praticien
     * après un délai de 20 minutes d'attente en salle d'attente.
     */
    public static function cancelUnansweredConsultations(): int
    {
        $cutoff = now()->subMinutes(20);

        $expired = static::where('status', 'en_attente')
            ->where('payment_status', 'paye')
            ->whereNull('scheduled_at')
            ->where('created_at', '<=', $cutoff)
            ->with(['doctor.hospital', 'patient'])
            ->get();

        $count = 0;
        foreach ($expired as $consultation) {
            DB::transaction(function () use ($consultation) {
                $consultation->update([
                    'status' => 'annulee',
                    'diagnosis' => "[Annulation automatique : délai d'attente de 20 minutes dépassé sans réponse du praticien. Fonds éligibles au remboursement/réaffectation]",
                ]);

                // Annulation du séquestre dans le portefeuille du praticien/hôpital
                $beneficiary = $consultation->doctor?->hospital ?? $consultation->doctor;
                if ($beneficiary) {
                    $wallet = $beneficiary->wallet;
                    $fee = (float) $consultation->consultation_fee;
                    if ($wallet && $fee > 0 && (float) $wallet->pending_balance >= $fee) {
                        $wallet->cancelHold(
                            $fee,
                            "Annulation du séquestre d'honoraires pour consultation expirée #{$consultation->id} (non prise en charge après 20 min)",
                            'consultation',
                            $consultation->id
                        );
                    }
                }
            });

            // Notifier le patient
            if ($consultation->patient) {
                NotificationService::send(
                    $consultation->patient,
                    'consultation_expired',
                    "Le Dr {$consultation->doctor?->name} n'a pas pu se libérer dans le délai de 20 minutes. Votre consultation a été annulée. Vous pouvez consulter un autre médecin disponible immédiatement ou demander votre remboursement."
                );
            }

            // Notifier le médecin
            if ($consultation->doctor) {
                NotificationService::send(
                    $consultation->doctor,
                    'consultation_expired_doctor',
                    "La demande de consultation #{$consultation->id} a expiré après 20 minutes d'attente sans prise en charge."
                );
            }

            $count++;
        }

        return $count;
    }
}

