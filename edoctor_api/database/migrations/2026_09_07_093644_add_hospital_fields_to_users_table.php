<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('hospital_id')->nullable()->after('role')->constrained()->nullOnDelete();
            $table->string('specialty')->nullable()->after('hospital_id');
            $table->string('license_number')->nullable()->after('specialty');
            $table->string('availability_status')->nullable()->after('license_number');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropConstrainedForeignId('hospital_id');
            $table->dropColumn(['specialty', 'license_number', 'availability_status']);
        });
    }
};