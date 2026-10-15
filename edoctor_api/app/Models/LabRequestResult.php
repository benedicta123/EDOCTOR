<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LabRequestResult extends Model
{
    use HasFactory;

    protected $fillable = [
        'lab_request_id',
        'file_path',
        'file_name',
        'mime_type',
        'file_size',
        'patient_notes',
        'uploaded_by',
    ];

    protected $casts = [
        'patient_notes' => 'encrypted',
    ];

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
