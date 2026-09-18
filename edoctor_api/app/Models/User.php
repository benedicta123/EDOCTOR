<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    // Au-delà de ce délai sans heartbeat, l'utilisateur est considéré hors ligne.
    public const ONLINE_THRESHOLD_MINUTES = 2;

    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'phone',
        'hospital_id',
        'specialty',
        'license_number',
        'availability_status', // nurse : disponible | en_mission ; doctor : (vide) | en_consultation
        'last_seen_at',
        'date_of_birth',
        'address',
        'medical_history_summary',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_seen_at' => 'datetime',
            'date_of_birth' => 'date',
            'password' => 'hashed',
        ];
    }

    public function isPatient(): bool { return $this->role === 'patient'; }
    public function isDoctor(): bool { return $this->role === 'doctor'; }
    public function isPharmacist(): bool { return $this->role === 'pharmacist'; }
    public function isNurse(): bool { return $this->role === 'nurse'; }
    public function isAdmin(): bool { return $this->role === 'admin'; }

    public function hospital(): BelongsTo
    {
        return $this->belongsTo(Hospital::class);
    }

    public function notifications(): HasMany
    {
        return $this->hasMany(Notification::class);
    }

    public function consultations(): HasMany
    {
        return $this->hasMany(Consultation::class, 'doctor_id');
    }

    public function patientConsultations(): HasMany
    {
        return $this->hasMany(Consultation::class, 'patient_id');
    }

    /**
     * En ligne = un heartbeat reçu récemment. Ne dépend d'aucun champ à
     * remettre à zéro manuellement — s'auto-corrige dès que l'app arrête d'appeler /heartbeat.
     */
    public function isOnline(): bool
    {
        return $this->last_seen_at !== null
            && $this->last_seen_at->gt(now()->subMinutes(self::ONLINE_THRESHOLD_MINUTES));
    }

    /**
     * Médecins réellement sollicitables maintenant :
     * - En ligne (heartbeat récent)
     * - Pas déjà en consultation
     * - Rattachés à un établissement hospitalier officiellement vérifié
     */
    public function scopeAvailableDoctors(Builder $query): Builder
    {
        return $query->where('role', 'doctor')
            ->where('availability_status', '!=', 'en_consultation')
            ->where('last_seen_at', '>=', now()->subMinutes(self::ONLINE_THRESHOLD_MINUTES))
            ->whereHas('hospital', function (Builder $q) {
                $q->where('status', 'verifie');
            });
    }
}