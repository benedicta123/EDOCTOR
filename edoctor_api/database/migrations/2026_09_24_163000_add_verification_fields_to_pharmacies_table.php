<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pharmacies', function (Blueprint $table) {
            $table->string('reference_id', 50)->nullable()->unique()->after('id');
            // en_attente | verifie | rejete | suspendu
            $table->string('status', 30)->default('en_attente')->after('name');
            $table->string('license_number')->nullable()->after('status');
            $table->string('order_number')->nullable()->after('license_number');
            $table->string('tax_number')->nullable()->after('order_number');
            $table->string('official_email')->nullable()->after('tax_number');
            $table->json('documents')->nullable()->after('opening_hours');
            $table->timestamp('verified_at')->nullable()->after('documents');
            $table->text('rejected_reason')->nullable()->after('verified_at');

            // Coordonnées GPS optionnelles à l'inscription initiale
            $table->decimal('latitude', 10, 7)->nullable()->change();
            $table->decimal('longitude', 10, 7)->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('pharmacies', function (Blueprint $table) {
            $table->dropColumn([
                'reference_id',
                'status',
                'license_number',
                'order_number',
                'tax_number',
                'official_email',
                'documents',
                'verified_at',
                'rejected_reason',
            ]);
        });
    }
};
