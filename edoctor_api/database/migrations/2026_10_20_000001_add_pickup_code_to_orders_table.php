<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'pickup_code')) {
                $table->string('pickup_code', 10)->nullable()->after('status');
                $table->timestamp('collected_at')->nullable()->after('pickup_code');
                $table->index('pickup_code');
            }
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'pickup_code')) {
                $table->dropIndex(['pickup_code']);
                $table->dropColumn(['pickup_code', 'collected_at']);
            }
        });
    }
};
