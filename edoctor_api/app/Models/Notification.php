<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Models\Traits\HasSafeUtf8Attributes;

class Notification extends Model
{
    use HasFactory, HasSafeUtf8Attributes;

    protected $fillable = ['user_id', 'type', 'content', 'read'];

    protected $casts = ['read' => 'boolean'];

    protected $appends = ['message'];

    public function getMessageAttribute(): string
    {
        return (string) ($this->content ?? '');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
