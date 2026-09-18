<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('hospitals', function (Blueprint $table) {
            // en_attente | verifie | rejete | suspendu
            $table->string('status')->default('en_attente')->after('name');
            $table->string('license_number')->nullable()->after('status');
            $table->string('tax_number')->nullable()->after('license_number');
            $table->string('official_email')->nullable()->after('tax_number');
            $table->string('phone')->nullable()->after('official_email');
            $table->string('license_document_path')->nullable()->after('phone');
            $table->timestamp('verified_at')->nullable()->after('license_document_path');
            $table->text('rejected_reason')->nullable()->after('verified_at');
        });
    }

    public function down(): void
    {
        Schema::table('hospitals', function (Blueprint $table) {
            $table->dropColumn([
                'status',
                'license_number',
                'tax_number',
                'official_email',
                'phone',
                'license_document_path',
                'verified_at',
                'rejected_reason',
            ]);
        });
    }
};
