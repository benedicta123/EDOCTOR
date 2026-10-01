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

    public function labRequest(): BelongsTo
    {
        return $this->belongsTo(LabRequest::class);
    }

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }
}
