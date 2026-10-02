<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Order extends Model
{
    use HasFactory;

    protected $fillable = [
        'patient_id', 'pharmacy_id', 'prescription_id', 'status', 'total_amount',
        'items_amount', 'edoctor_fee', 'delivery_fee', 'delivery_distance_km',
    ];

    protected $casts = [
        'total_amount' => 'decimal:2',
        'items_amount' => 'decimal:2',
        'edoctor_fee' => 'decimal:2',
        'delivery_fee' => 'decimal:2',
        'delivery_distance_km' => 'decimal:2',
    ];

    public function patient(): BelongsTo
    {
        return $this->belongsTo(User::class, 'patient_id');
    }

    public function pharmacy(): BelongsTo
    {
        return $this->belongsTo(Pharmacy::class);
    }

    public function prescription(): BelongsTo
    {
        return $this->belongsTo(Prescription::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function payment(): HasOne
    {
        return $this->hasOne(Payment::class);
    }

    public function delivery(): HasOne
    {
        return $this->hasOne(Delivery::class);
    }
}
