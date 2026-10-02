<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payment extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id', 'consultation_id', 'method', 'amount',
        'partner_share', 'edoctor_fee', 'courier_share',
        'status', 'transaction_ref',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'partner_share' => 'decimal:2',
        'edoctor_fee' => 'decimal:2',
        'courier_share' => 'decimal:2',
    ];

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function consultation(): BelongsTo
    {
        return $this->belongsTo(Consultation::class);
    }
}
