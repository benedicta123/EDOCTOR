<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Pharmacy extends Model
{
    use HasFactory;

    protected $fillable = [
        'owner_id', 'reference_id', 'name', 'status', 'license_number', 'order_number',
        'tax_number', 'official_email', 'address', 'latitude', 'longitude', 'phone',
        'opening_hours', 'documents', 'verified_at', 'rejected_reason',
    ];

    protected $casts = [
        'opening_hours' => 'array',
        'documents' => 'array',
        'verified_at' => 'datetime',
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
    ];

    public function isVerified(): bool
    {
        return $this->status === 'verifie';
    }

    public function isPending(): bool
    {
        return $this->status === 'en_attente';
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function stocks(): HasMany
    {
        return $this->hasMany(PharmacyStock::class);
    }

    public function wallet(): \Illuminate\Database\Eloquent\Relations\MorphOne
    {
        return $this->morphOne(Wallet::class, 'holder');
    }

    public function getOrCreateWallet(): Wallet
    {
        return $this->wallet()->firstOrCreate([], [
            'balance' => 0.00,
            'pending_balance' => 0.00,
            'currency' => 'XOF',
            'is_active' => true,
        ]);
    }
}
