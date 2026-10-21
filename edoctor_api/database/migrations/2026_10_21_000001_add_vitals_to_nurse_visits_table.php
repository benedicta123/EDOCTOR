<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('nurse_visits', function (Blueprint $table) {
            $table->string('blood_pressure', 50)->nullable()->after('report'); // ex: 12/8 mmHg
            $table->string('blood_glucose', 50)->nullable()->after('blood_pressure'); // ex: 1.05 g/L
            $table->string('temperature', 50)->nullable()->after('blood_glucose'); // ex: 37.2 °C
            $table->string('heart_rate', 50)->nullable()->after('temperature'); // ex: 74 bpm
            $table->json('acts_performed')->nullable()->after('heart_rate'); // ["Pansement stérile", "Injection IM"]
            $table->timestamp('completed_at')->nullable()->after('acts_performed');
        });
    }

    public function down(): void
    {
        Schema::table('nurse_visits', function (Blueprint $table) {
            $table->dropColumn([
                'blood_pressure',
                'blood_glucose',
                'temperature',
                'heart_rate',
                'acts_performed',
                'completed_at',
            ]);
        });
    }
};
