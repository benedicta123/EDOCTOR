<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Hospital extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'address',
        'latitude',
        'longitude',
        'status',
        'license_number',
        'tax_number',
        'official_email',
        'phone',
        'license_document_path',
        'verified_at',
        'rejected_reason',
    ];

    protected function casts(): array
    {
        return [
            'verified_at' => 'datetime',
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
        ];
    }

    public function isVerified(): bool
    {
        return $this->status === 'verifie';
    }

    public function scopeVerified(Builder $query): Builder
    {
        return $query->where('status', 'verifie');
    }

    public function admins(): HasMany
    {
        return $this->hasMany(User::class)->where('role', 'admin');
    }

    public function doctors(): HasMany
    {
        return $this->hasMany(User::class)->where('role', 'doctor');
    }

    public function nurses(): HasMany
    {
        return $this->hasMany(User::class)->where('role', 'nurse');
    }

    public function availableNurses(): HasMany
    {
        return $this->nurses()->where('availability_status', 'disponible');
    }

    public function nurseVisits(): HasMany
    {
        return $this->hasMany(NurseVisit::class);
    }
}
