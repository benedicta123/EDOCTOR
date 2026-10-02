<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class Delivery extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id', 'courier_name', 'status', 'address', 'tracking_code',
        'distance_km', 'delivery_fee', 'courier_share', 'edoctor_share',
    ];

    protected $casts = [
        'distance_km' => 'decimal:2',
        'delivery_fee' => 'decimal:2',
        'courier_share' => 'decimal:2',
        'edoctor_share' => 'decimal:2',
    ];

    protected static function booted(): void
    {
        static::creating(function (Delivery $delivery) {
            $delivery->tracking_code ??= strtoupper(Str::random(8));
        });
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }
}