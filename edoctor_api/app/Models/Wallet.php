<?php

namespace App\Models;

use Exception;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Support\Facades\DB;

class Wallet extends Model
{
    use HasFactory;

    protected $fillable = [
        'holder_type',
        'holder_id',
        'balance',
        'pending_balance',
        'currency',
        'payout_channel',
        'payout_account',
        'payout_account_name',
        'is_active',
    ];

    protected $casts = [
        'balance' => 'decimal:2',
        'pending_balance' => 'decimal:2',
        'is_active' => 'boolean',
    ];

    public function holder(): MorphTo
    {
        return $this->morphTo();
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class)->latest();
    }

    public function payoutRequests(): HasMany
    {
        return $this->hasMany(PayoutRequest::class)->latest();
    }

    /**
     * Crédite directement le solde disponible (ex: acte finalisé).
     */
    public function credit(float $amount, string $description, ?string $sourceType = null, ?int $sourceId = null, ?array $metadata = null): WalletTransaction
    {
        if ($amount <= 0) {
            throw new Exception("Le montant à créditer doit être supérieur à zéro.");
        }

        return DB::transaction(function () use ($amount, $description, $sourceType, $sourceId, $metadata) {
            $this->refresh();
            $before = (float) $this->balance;
            $after = $before + $amount;

            $this->update(['balance' => $after]);

            return $this->transactions()->create([
                'type' => 'credit',
                'amount' => $amount,
                'balance_before' => $before,
                'balance_after' => $after,
                'source_type' => $sourceType,
                'source_id' => $sourceId,
                'description' => $description,
                'metadata' => $metadata,
            ]);
        });
    }

    /**
     * Place des fonds sous séquestre (pending_balance) en attendant la clôture de l'acte.
     */
    public function hold(float $amount, string $description, ?string $sourceType = null, ?int $sourceId = null, ?array $metadata = null): WalletTransaction
    {
        if ($amount <= 0) {
            throw new Exception("Le montant à séquestrer doit être supérieur à zéro.");
        }

        return DB::transaction(function () use ($amount, $description, $sourceType, $sourceId, $metadata) {
            $this->refresh();
            $this->increment('pending_balance', $amount);

            return $this->transactions()->create([
                'type' => 'hold',
                'amount' => $amount,
                'balance_before' => $this->balance,
                'balance_after' => $this->balance,
                'source_type' => $sourceType,
                'source_id' => $sourceId,
                'description' => $description,
                'metadata' => $metadata,
            ]);
        });
    }

    /**
     * Libère les fonds du séquestre vers le solde disponible (consultation ou commande achevée).
     */
    public function release(float $amount, string $description, ?string $sourceType = null, ?int $sourceId = null, ?array $metadata = null): WalletTransaction
    {
        if ($amount <= 0) {
            throw new Exception("Le montant à libérer doit être supérieur à zéro.");
        }

        return DB::transaction(function () use ($amount, $description, $sourceType, $sourceId, $metadata) {
            $this->refresh();
            $currentPending = (float) $this->pending_balance;
            $newPending = max(0.0, $currentPending - $amount);
            $before = (float) $this->balance;
            $after = $before + $amount;

            $this->update([
                'pending_balance' => $newPending,
                'balance' => $after,
            ]);

            return $this->transactions()->create([
                'type' => 'release',
                'amount' => $amount,
                'balance_before' => $before,
                'balance_after' => $after,
                'source_type' => $sourceType,
                'source_id' => $sourceId,
                'description' => $description,
                'metadata' => $metadata,
            ]);
        });
    }

    /**
     * Annule un montant placé sous séquestre (ex: consultation annulée avant exécution).
     */
    public function cancelHold(float $amount, string $description, ?string $sourceType = null, ?int $sourceId = null, ?array $metadata = null): WalletTransaction
    {
        if ($amount <= 0) {
            throw new Exception("Le montant à débloquer doit être supérieur à zéro.");
        }

        return DB::transaction(function () use ($amount, $description, $sourceType, $sourceId, $metadata) {
            $this->refresh();
            $currentPending = (float) $this->pending_balance;
            $newPending = max(0.0, $currentPending - $amount);

            $this->update(['pending_balance' => $newPending]);

            return $this->transactions()->create([
                'type' => 'cancel_hold',
                'amount' => $amount,
                'balance_before' => $this->balance,
                'balance_after' => $this->balance,
                'source_type' => $sourceType,
                'source_id' => $sourceId,
                'description' => $description,
                'metadata' => $metadata,
            ]);
        });
    }

    /**
     * Débite le solde disponible pour un reversement (payout).
     */
    public function debit(float $amount, string $description, ?string $sourceType = null, ?int $sourceId = null, ?array $metadata = null): WalletTransaction
    {
        if ($amount <= 0) {
            throw new Exception("Le montant à débiter doit être supérieur à zéro.");
        }

        return DB::transaction(function () use ($amount, $description, $sourceType, $sourceId, $metadata) {
            $this->refresh();
            $before = (float) $this->balance;

            if ($before < $amount) {
                throw new Exception("Solde insuffisant pour exécuter cette opération.");
            }

            $after = $before - $amount;
            $this->update(['balance' => $after]);

            return $this->transactions()->create([
                'type' => 'debit',
                'amount' => $amount,
                'balance_before' => $before,
                'balance_after' => $after,
                'source_type' => $sourceType,
                'source_id' => $sourceId,
                'description' => $description,
                'metadata' => $metadata,
            ]);
        });
    }
}
