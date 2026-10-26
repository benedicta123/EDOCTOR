<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Crypt;
use App\Models\Traits\HasSafeUtf8Attributes;

class LabRequestResult extends Model
{
    use HasFactory, HasSafeUtf8Attributes;

    protected $fillable = [
        'lab_request_id',
        'file_path',
        'file_name',
        'mime_type',
        'file_size',
        'patient_notes',
        'uploaded_by',
    ];

    protected $casts = [];

    protected function patientNotes(): Attribute
    {
        return Attribute::make(
            get: fn ($value) => self::safeDecrypt($value),
            set: fn ($value) => self::safeEncrypt($value)
        );
    }

    public function labRequest(): BelongsTo
    {
        return $this->belongsTo(LabRequest::class);
    }

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    /**
     * Génère dynamiquement une URL signée temporaire (24h) pour l'accès sécurisé
     * au document médical stocké sur le disque privé.
     */
    public function getFilePathAttribute($value): string
    {
        if (empty($value)) {
            return '';
        }

        // Support rétroactif des URL complètes historiques
        if (str_starts_with($value, 'http://') || str_starts_with($value, 'https://')) {
            return $value;
        }

        // URL signée cryptographiquement (HMAC)
        return \Illuminate\Support\Facades\URL::temporarySignedRoute(
            'lab.secure-view',
            now()->addHours(24),
            ['result' => $this->id]
        );
    }
}
