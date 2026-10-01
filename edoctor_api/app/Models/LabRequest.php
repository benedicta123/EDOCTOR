<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LabRequest extends Model
{
    use HasFactory;

    protected $fillable = [
        'reference_code',
        'consultation_id',
        'doctor_id',
        'patient_id',
        'clinical_notes',
        'urgency_level',
        'fasting_required',
        'status',
        'doctor_review_notes',
        'results_uploaded_at',
        'reviewed_at',
    ];

    protected $casts = [
        'fasting_required' => 'boolean',
        'results_uploaded_at' => 'datetime',
        'reviewed_at' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::creating(function (LabRequest $labRequest) {
            if (empty($labRequest->reference_code)) {
                $labRequest->reference_code = static::generateReferenceCode(
                    $labRequest->doctor_id,
                    $labRequest->created_at ?? now()
                );
            }
        });
    }

    /**
     * Génère un code de référence structuré unique : LAB-[AAMM]-[HOPITAL]-[4CHARS]
     * Ex: LAB-2610-CHU-8F2B
     */
    public static function generateReferenceCode(?int $doctorId = null, ?\DateTimeInterface $date = null): string
    {
        $dt = $date ? \Carbon\Carbon::parse($date) : now();
        $yearMonth = $dt->format('ym');
        $hospitalCode = 'EDO';

        if ($doctorId) {
            $doctor = User::with('hospital')->find($doctorId);
            if ($doctor && $doctor->hospital) {
                $hospitalCode = Consultation::extractHospitalCode($doctor->hospital->name);
            }
        }

        $chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
        $charLen = strlen($chars);

        do {
            $suffix = '';
            for ($i = 0; $i < 4; $i++) {
                $suffix .= $chars[random_int(0, $charLen - 1)];
            }
            $code = "LAB-{$yearMonth}-{$hospitalCode}-{$suffix}";
        } while (static::where('reference_code', $code)->exists());

        return $code;
    }

    public function consultation(): BelongsTo
    {
        return $this->belongsTo(Consultation::class);
    }

    public function doctor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'doctor_id');
    }

    public function patient(): BelongsTo
    {
        return $this->belongsTo(User::class, 'patient_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(LabRequestItem::class);
    }

    public function results(): HasMany
    {
        return $this->hasMany(LabRequestResult::class);
    }

    public function isParticipant(User $user): bool
    {
        return $user->id === $this->patient_id || $user->id === $this->doctor_id;
    }
}
