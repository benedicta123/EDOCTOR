<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('notifications')
            ->where('type', 'hospital_verified')
            ->update([
                'content' => "Votre hôpital est désormais certifié et homologué par eDoctor. Vous pouvez dès à présent démarrer vos activités médicales et accueillir vos patients en toute conformité.",
            ]);
    }

    public function down(): void
    {
        // Pas de retour arrière nécessaire
    }
};
