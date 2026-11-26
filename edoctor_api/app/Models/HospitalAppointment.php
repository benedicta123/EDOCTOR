<?php

namespace App\Models;

use App\Models\Traits\HasSafeUtf8Attributes;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class HospitalAppointment extends Model
{
    use HasFactory, HasSafeUtf8Attributes;

    protected $fillable = [
        'reference_code',
        'hospital_id',
        'patient_id',
        'doctor_id',
        'department',
        'appointment_date',
        'time_slot',
        'queue_number',
        'reason',
        'status',
        'consultation_fee',
        'doctor_notes',
        'checked_in_at',
        'called_at',
        'completed_at',
        'cancelled_at',
        'assigned_by',
    ];

    protected function casts(): array
    {
        return [
            'appointment_date' => 'date',
            'checked_in_at' => 'datetime',
            'called_at' => 'datetime',
            'completed_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'consultation_fee' => 'decimal:2',
            'queue_number' => 'integer',
        ];
    }

    public function hospital(): BelongsTo
    {
        return $this->belongsTo(Hospital::class);
    }

    public function patient(): BelongsTo
    {
        return $this->belongsTo(User::class, 'patient_id');
    }

    public function doctor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'doctor_id');
    }

    public function assignedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_by');
    }

    public function scopeToday(Builder $query): Builder
    {
        return $query->whereDate('appointment_date', now()->toDateString());
    }

    public function scopeForHospital(Builder $query, int $hospitalId): Builder
    {
        return $query->where('hospital_id', $hospitalId);
    }

    public function scopeForDoctor(Builder $query, int $doctorId): Builder
    {
        return $query->where('doctor_id', $doctorId);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->whereNotIn('status', ['termine', 'annule']);
    }

    /**
     * Génère une référence unique humaine : RDV-AAMM-HOSP-XXXX
     */
    public static function generateReferenceCode(Hospital $hospital): string
    {
        $prefix = 'RDV-' . date('ym');
        $hospitalTag = strtoupper(substr(preg_replace('/[^A-Za-z0-9]/', '', $hospital->name) ?? 'HOSP', 0, 4));
        $random = strtoupper(bin2hex(random_bytes(2)));

        return "{$prefix}-{$hospitalTag}-{$random}";
    }

    /**
     * Détermine le prochain numéro d'ordre de passage du jour dans l'hôpital
     */
    public static function nextQueueNumber(int $hospitalId, string $date): int
    {
        $max = self::where('hospital_id', $hospitalId)
            ->whereDate('appointment_date', $date)
            ->max('queue_number');

        return ($max ?? 0) + 1;
    }
}
