<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class ListHospitalAdmins extends Command
{
    protected $signature = 'edoctor:list-hospital-admins {--reset-password= : Réinitialise le mot de passe de tous les administrateurs d\'hôpitaux avec cette valeur}';
    protected $description = 'Affiche la liste de tous les administrateurs d\'hôpitaux (cliniques, CHU, centres médicaux)';

    public function handle(): int
    {
        $admins = User::where(function ($q) {
            $q->where('role', 'admin')
              ->orWhere('role', 'hospital_admin');
        })
        ->whereNotNull('hospital_id')
        ->with('hospital')
        ->get();

        if ($admins->isEmpty()) {
            $this->warn('Aucun administrateur d\'hôpital trouvé dans la base de données.');
            return self::SUCCESS;
        }

        $resetPassword = $this->option('reset-password');
        if ($resetPassword) {
            $hashed = Hash::make($resetPassword);
            foreach ($admins as $admin) {
                $admin->password = $hashed;
                $admin->save();
            }
            $this->info("✓ Le mot de passe de tous les administrateurs d'hôpitaux a été réinitialisé à : {$resetPassword}");
            $this->newLine();
        }

        $headers = ['ID', 'Nom Admin', 'Email', 'Téléphone', 'Hôpital Administré', 'Statut Hôpital'];
        $rows = $admins->map(function ($admin) {
            return [
                $admin->id,
                $admin->name,
                $admin->email,
                $admin->phone ?? 'N/A',
                $admin->hospital ? $admin->hospital->name : ('Hôpital #' . $admin->hospital_id),
                $admin->hospital ? strtoupper($admin->hospital->status ?? 'ACTIF') : 'N/A',
            ];
        });

        $this->table($headers, $rows);

        $this->newLine();
        $this->comment('Note sécurité : Les mots de passe sont hachés et chiffrés en base.');
        if (!$resetPassword) {
            $this->comment('Pour définir un mot de passe connu (ex: Password123!) pour vos tests :');
            $this->info('php artisan edoctor:list-hospital-admins --reset-password=Password123!');
        }

        return self::SUCCESS;
    }
}
