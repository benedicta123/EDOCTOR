<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Medication extends Model
{
    use HasFactory;

    protected $fillable = [
        'name', 'dosage', 'form', 'category', 'requires_prescription',
    ];

    protected $casts = [
        'requires_prescription' => 'boolean',
    ];

    public function stocks(): HasMany
    {
        return $this->hasMany(PharmacyStock::class);
    }
}
