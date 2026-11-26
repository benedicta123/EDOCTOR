<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('hospital_appointments', function (Blueprint $table) {
            $table->id();
            $table->string('reference_code')->unique(); // Ex: RDV-2611-CHU-4A9B
            $table->foreignId('hospital_id')->constrained('hospitals')->cascadeOnDelete();
            $table->foreignId('patient_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('doctor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('department'); // Médecine Générale, Pédiatrie, Gynécologie, etc.
            $table->date('appointment_date');
            $table->string('time_slot'); // Ex: 08:30 - 09:00
            $table->unsignedInteger('queue_number')->nullable(); // Numéro de passage du jour
            $table->text('reason')->nullable(); // Motif de consultation
            
            // Cycle de vie : reserve -> en_attente (arrivé) -> en_consultation -> termine | annule
            $table->string('status')->default('reserve');
            
            $table->decimal('consultation_fee', 10, 2)->default(0);
            $table->text('doctor_notes')->nullable(); // Compte-rendu succinct
            
            // Horodatage du parcours physique
            $table->timestamp('checked_in_at')->nullable(); // Heure d'arrivée validée par l'accueil
            $table->timestamp('called_at')->nullable();     // Heure d'entrée dans le bureau du médecin
            $table->timestamp('completed_at')->nullable();  // Clôture du rendez-vous
            $table->timestamp('cancelled_at')->nullable();
            
            $table->foreignId('assigned_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['hospital_id', 'appointment_date']);
            $table->index(['doctor_id', 'appointment_date']);
            $table->index(['patient_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('hospital_appointments');
    }
};
