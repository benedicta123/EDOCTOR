<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Champs de suspension / modération sur les utilisateurs
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_suspended')->default(false)->after('password');
            $table->text('suspension_reason')->nullable()->after('is_suspended');
            $table->timestamp('suspended_at')->nullable()->after('suspension_reason');
        });

        // 2. Table du journal des réclamations et litiges (patients / praticiens)
        Schema::create('claims', function (Blueprint $table) {
            $table->id();
            $table->string('reference_id', 50)->unique(); // Ex: REC-2026-XXXX
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->string('target_type', 50)->nullable(); // hospital, doctor, pharmacy, consultation, order, platform
            $table->unsignedBigInteger('target_id')->nullable();
            $table->string('category', 60); // medical, facturation, dispensation, comportement, technique, autre
            $table->string('priority', 30)->default('normale'); // faible, normale, haute, urgente
            $table->string('subject', 255);
            $table->text('description');
            $table->string('status', 30)->default('ouvert'); // ouvert, en_cours, resolu, rejete
            $table->text('resolution_notes')->nullable();
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'priority']);
            $table->index(['target_type', 'target_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('claims');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['is_suspended', 'suspension_reason', 'suspended_at']);
        });
    }
};
