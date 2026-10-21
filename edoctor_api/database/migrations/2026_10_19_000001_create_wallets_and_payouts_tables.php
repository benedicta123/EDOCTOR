<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Table des portefeuilles électroniques (Wallets)
        Schema::create('wallets', function (Blueprint $table) {
            $table->id();
            // Relation polymorphique : User (praticien/coursier), Hospital, Pharmacy
            $table->string('holder_type'); // 'App\Models\User', 'App\Models\Hospital', 'App\Models\Pharmacy'
            $table->unsignedBigInteger('holder_id');
            $table->index(['holder_type', 'holder_id'], 'wallet_holder_index');
            
            // Soldes en Francs CFA
            $table->decimal('balance', 12, 2)->default(0.00); // Solde disponible et retirable
            $table->decimal('pending_balance', 12, 2)->default(0.00); // Solde sous séquestre (escrow)
            $table->string('currency', 5)->default('XOF'); // FCFA
            
            // Coordonnées de reversement par défaut
            $table->string('payout_channel')->nullable(); // 't-money', 'flooz', 'virement_bancaire'
            $table->string('payout_account')->nullable(); // Numéro Mobile Money (+228...) ou IBAN
            $table->string('payout_account_name')->nullable(); // Nom du titulaire certifié
            
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        // 2. Table du livre journal des transactions de portefeuille (Audit Trail)
        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('wallet_id')->constrained('wallets')->cascadeOnDelete();
            
            // 'credit' (gain), 'debit' (retrait), 'hold' (séquestre), 'release' (libération), 'refund' (remboursement)
            $table->string('type', 30);
            $table->decimal('amount', 12, 2);
            $table->decimal('balance_before', 12, 2);
            $table->decimal('balance_after', 12, 2);
            
            // Référence de l'acte générateur
            $table->string('source_type')->nullable(); // 'consultation', 'order', 'payout', 'adjustment'
            $table->unsignedBigInteger('source_id')->nullable();
            $table->string('description')->nullable();
            $table->json('metadata')->nullable();
            
            $table->timestamps();
            
            $table->index(['wallet_id', 'created_at']);
        });

        // 3. Table des demandes de reversement (Payout Requests)
        Schema::create('payout_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('wallet_id')->constrained('wallets')->cascadeOnDelete();
            
            $table->decimal('amount', 12, 2); // Montant brut demandé
            $table->decimal('fee', 12, 2)->default(0.00); // Frais éventuels de transfert Mobile Money
            $table->decimal('net_amount', 12, 2); // Montant net viré au bénéficiaire
            
            $table->string('payout_method', 30); // 't-money', 'flooz', 'virement_bancaire'
            $table->string('account_number'); // Numéro Mobile Money (+228...) ou RIB
            $table->string('account_name')->nullable(); // Nom vérifié du bénéficiaire
            
            // 'en_attente', 'en_cours', 'traite', 'rejete'
            $table->string('status', 30)->default('en_attente');
            $table->string('transaction_ref')->nullable(); // Réf transaction opérateur (FedaPay Payout / T-Money)
            $table->text('notes')->nullable(); // Motif de rejet ou observation admin
            
            $table->foreignId('processed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();
            
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payout_requests');
        Schema::dropIfExists('wallet_transactions');
        Schema::dropIfExists('wallets');
    }
};
