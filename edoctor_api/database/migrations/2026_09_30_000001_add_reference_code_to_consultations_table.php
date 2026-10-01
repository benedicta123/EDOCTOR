<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use App\Models\Consultation;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('consultations', function (Blueprint $table) {
            $table->string('reference_code', 32)->nullable()->unique()->after('id');
        });

        // Génération rétroactive des codes de référence pour les consultations existantes
        $consultations = Consultation::with('doctor.hospital')->get();
        foreach ($consultations as $consultation) {
            if (empty($consultation->reference_code)) {
                $consultation->reference_code = Consultation::generateReferenceCode(
                    $consultation->doctor_id,
                    $consultation->created_at
                );
                $consultation->saveQuietly();
            }
        }
    }

    public function down(): void
    {
        Schema::table('consultations', function (Blueprint $table) {
            $table->dropColumn('reference_code');
        });
    }
};
