<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Facades\DB;
use App\Services\NotificationService;

class Consultation extends Model
{
    use HasFactory;

    protected $fillable = [
        'reference_code', 'patient_id', 'doctor_id', 'status', 'scheduled_at', 'started_at', 'ended_at',
        'diagnosis',
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
        $words = preg_split('/[\s,\-\']+/u', trim($name));
        $stopWords = ['de', 'du', 'la', 'le', 'les', 'des', 'et', 'd', 'l', 'au', 'aux'];
        $filtered = [];

        foreach ($words as $w) {
            $clean = preg_replace('/[^\p{L}\p{N}]/u', '', $w);
            if (mb_strlen($clean) > 0 && !in_array(mb_strtolower($clean), $stopWords)) {
                $filtered[] = $clean;
            }
        }

        $initials = '';
        foreach ($filtered as $w) {
            $initials .= mb_substr($w, 0, 1);
            if (mb_strlen($initials) >= 4) {
                break;
            }
        }

        if (mb_strlen($initials) >= 2) {
            return strtoupper(substr(iconv('UTF-8', 'ASCII//TRANSLIT', $initials) ?: $initials, 0, 4));
        }

        $cleanAll = preg_replace('/[^a-zA-Z0-9]/', '', iconv('UTF-8', 'ASCII//TRANSLIT', $name) ?: $name);
        return strtoupper(substr($cleanAll, 0, 3)) ?: 'EDO';
    }

    protected $casts = [
        'scheduled_at' => 'datetime',
        'started_at' => 'datetime',
        'ended_at' => 'datetime',
    ];

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

    public function isParticipant(User $user): bool
    {
        return $user->id === $this->patient_id || $user->id === $this->doctor_id;
    }

    /**
     * Clôture automatiquement les téléconsultations en cours depuis plus de 2 heures (120 minutes).
     */
    public static function closeExpiredConsultations(): int
    {
        $cutoff = now()->subHours(2);

        $expired = static::where('status', 'en_cours')
            ->whereNotNull('started_at')
            ->where('started_at', '<=', $cutoff)
            ->with(['doctor', 'patient'])
            ->get();

        $count = 0;
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
}

