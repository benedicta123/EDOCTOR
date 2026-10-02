<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Tarif de consultation configurable pour les hôpitaux
        Schema::table('hospitals', function (Blueprint $table) {
            if (! Schema::hasColumn('hospitals', 'consultation_fee')) {
                $table->decimal('consultation_fee', 10, 2)->default(3000.00)->after('phone');
            }
        });

        // 2. Possibilité pour un médecin d'avoir un tarif spécifique optionnel
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'consultation_fee')) {
                $table->decimal('consultation_fee', 10, 2)->nullable()->after('hospital_id');
            }
        });

        // 3. Découpage financier pour chaque consultation médicale
        Schema::table('consultations', function (Blueprint $table) {
            if (! Schema::hasColumn('consultations', 'consultation_fee')) {
                $table->decimal('consultation_fee', 10, 2)->default(3000.00)->after('status');
                $table->decimal('edoctor_fee', 10, 2)->default(600.00)->after('consultation_fee');
                $table->decimal('total_amount', 10, 2)->default(3600.00)->after('edoctor_fee');
                $table->string('payment_status')->default('en_attente')->after('total_amount');
            }
        });

        // 4. Découpage financier pour chaque commande pharmacie
        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'items_amount')) {
                $table->decimal('items_amount', 10, 2)->default(0.00)->after('total_amount');
                $table->decimal('edoctor_fee', 10, 2)->default(150.00)->after('items_amount');
                $table->decimal('delivery_fee', 10, 2)->default(0.00)->after('edoctor_fee');
                $table->decimal('delivery_distance_km', 6, 2)->default(0.00)->after('delivery_fee');
            }
        });

        // 5. Suivi kilométrique et partage coursier / eDoctor
        Schema::table('deliveries', function (Blueprint $table) {
            if (! Schema::hasColumn('deliveries', 'distance_km')) {
                $table->decimal('distance_km', 6, 2)->default(0.00)->after('address');
                $table->decimal('delivery_fee', 10, 2)->default(0.00)->after('distance_km');
                $table->decimal('courier_share', 10, 2)->default(0.00)->after('delivery_fee');
                $table->decimal('edoctor_share', 10, 2)->default(0.00)->after('courier_share');
            }
        });

        // 6. Split des paiements et support des paiements de consultation
        Schema::table('payments', function (Blueprint $table) {
            if (! Schema::hasColumn('payments', 'consultation_id')) {
                $table->foreignId('consultation_id')->nullable()->after('order_id')->constrained()->nullOnDelete();
                $table->decimal('partner_share', 10, 2)->default(0.00)->after('amount');
                $table->decimal('edoctor_fee', 10, 2)->default(0.00)->after('partner_share');
                $table->decimal('courier_share', 10, 2)->default(0.00)->after('edoctor_fee');
            }
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            if (Schema::hasColumn('payments', 'consultation_id')) {
                $table->dropConstrainedForeignId('consultation_id');
                $table->dropColumn(['partner_share', 'edoctor_fee', 'courier_share']);
            }
        });

        Schema::table('deliveries', function (Blueprint $table) {
            if (Schema::hasColumn('deliveries', 'distance_km')) {
                $table->dropColumn(['distance_km', 'delivery_fee', 'courier_share', 'edoctor_share']);
            }
        });

        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'items_amount')) {
                $table->dropColumn(['items_amount', 'edoctor_fee', 'delivery_fee', 'delivery_distance_km']);
            }
        });

        Schema::table('consultations', function (Blueprint $table) {
            if (Schema::hasColumn('consultations', 'consultation_fee')) {
                $table->dropColumn(['consultation_fee', 'edoctor_fee', 'total_amount', 'payment_status']);
            }
        });

        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'consultation_fee')) {
                $table->dropColumn('consultation_fee');
            }
        });

        Schema::table('hospitals', function (Blueprint $table) {
            if (Schema::hasColumn('hospitals', 'consultation_fee')) {
                $table->dropColumn('consultation_fee');
            }
        });
    }
};
