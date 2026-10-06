<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Prescription extends Model
{
    use HasFactory;

    protected $fillable = [
        'consultation_id', 'doctor_id', 'patient_id', 'status', 'home_care_recommended',
    ];

    protected $casts = [
        'home_care_recommended' => 'boolean',
    ];

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
        return $this->hasMany(PrescriptionItem::class);
    }

    // Relation NurseVisit (0..1) — utilisée une fois le module soins à domicile construit.
    public function nurseVisit(): HasOne
    {
        return $this->hasOne(NurseVisit::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function order(): HasOne
    {
        return $this->hasOne(Order::class)->latestOfMany();
    }

    public function isParticipant(User $user): bool
    {
        return $user->id === $this->patient_id || $user->id === $this->doctor_id;
    }
}
