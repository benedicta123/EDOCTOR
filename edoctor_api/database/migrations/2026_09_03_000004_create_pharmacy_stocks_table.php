<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pharmacy_stocks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pharmacy_id')->constrained()->cascadeOnDelete();
            $table->foreignId('medication_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('quantity')->default(0);
            $table->decimal('price', 10, 2);
            $table->timestamps();

            $table->unique(['pharmacy_id', 'medication_id']); // un seul stock par pharmacie/médicament
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pharmacy_stocks');
    }
};
