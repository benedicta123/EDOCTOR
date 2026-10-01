<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Table principale des demandes de bilans et examens complémentaires
        Schema::create('lab_requests', function (Blueprint $table) {
            $table->id();
            $table->string('reference_code')->unique(); // Ex: LAB-2610-CHU-8F2B
            $table->foreignId('consultation_id')->constrained()->cascadeOnDelete();
            $table->foreignId('doctor_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('patient_id')->constrained('users')->cascadeOnDelete();
            
            // Indications cliniques & consignes du médecin
            $table->text('clinical_notes')->nullable();
            $table->string('urgency_level')->default('normal'); // 'normal' | 'urgent'
            $table->boolean('fasting_required')->default(false); // À jeun
            
            // Cycle de vie : prescrit -> en_attente_resultats -> resultats_recus -> analyse_terminee | annule
            $table->string('status')->default('prescrit');
            
            // Analyse & synthèse du médecin après réception des résultats
            $table->text('doctor_review_notes')->nullable();
            $table->timestamp('results_uploaded_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();
        });

        // 2. Éléments prescrits (analyses sanguines, parasitologie, imagerie...)
        Schema::create('lab_request_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('lab_request_id')->constrained()->cascadeOnDelete();
            $table->string('name'); // Ex: Goutte Épaisse & Frottis Sanguin (GE/FS)
            $table->string('category')->default('biologie'); // biologie, imagerie, parasitologie, bacteriologie, autre
            $table->string('instructions')->nullable(); // Ex: Prélèvement à jeun, 3 tubes EDTA
            $table->timestamps();
        });

        // 3. Fichiers et documents de résultats téléversés par le patient ou le labo
        Schema::create('lab_request_results', function (Blueprint $table) {
            $table->id();
            $table->foreignId('lab_request_id')->constrained()->cascadeOnDelete();
            $table->string('file_path');
            $table->string('file_name');
            $table->string('mime_type')->nullable();
            $table->unsignedBigInteger('file_size')->nullable();
            $table->text('patient_notes')->nullable();
            $table->foreignId('uploaded_by')->constrained('users')->cascadeOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lab_request_results');
        Schema::dropIfExists('lab_request_items');
        Schema::dropIfExists('lab_requests');
    }
};
