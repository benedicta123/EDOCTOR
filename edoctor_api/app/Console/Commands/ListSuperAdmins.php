<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class ListSuperAdmins extends Command
{
    protected $signature = 'edoctor:list-superadmins {--reset-password= : Réinitialise le mot de passe de tous les super-administrateurs avec cette valeur} {--all : Affiche tous les administrateurs y compris ceux rattachés à un hôpital}';
    protected $description = 'Affiche la liste de tous les Super-Administrateurs de la plateforme eDoctor';

    public function handle(): int
    {
        $showAll = $this->option('all');

        $query = User::query();

        if ($showAll) {
            $query->whereIn('role', ['admin', 'superadmin', 'hospital_admin'])->with('hospital');
        } else {
            // Super-Admin National : role admin ou superadmin avec hospital_id null
            $query->where(function ($q) {
                $q->where('role', 'superadmin')
                  ->orWhere(function ($sub) {
                      $sub->where('role', 'admin')->whereNull('hospital_id');
                  });
            })->with('hospital');
        }

        $admins = $query->get();

        if ($admins->isEmpty()) {
            $this->warn($showAll
                ? 'Aucun administrateur trouvé dans la base de données.'
                : 'Aucun super-administrateur national trouvé (hospital_id null). Utilisez --all pour voir les administrateurs d\'hôpitaux.');
            return self::SUCCESS;
        }

        $resetPassword = $this->option('reset-password');
        if ($resetPassword) {
            $hashed = Hash::make($resetPassword);
            foreach ($admins as $admin) {
                $admin->password = $hashed;
                $admin->save();
            }
            $this->info("✓ Le mot de passe de ces administrateurs a été réinitialisé à : {$resetPassword}");
            $this->newLine();
        }

        $headers = ['ID', 'Nom', 'Email', 'Téléphone', 'Rôle', 'Type / Hôpital'];
        $rows = $admins->map(function ($admin) {
            $type = $admin->hospital_id === null
                ? 'SUPER-ADMIN NATIONAL'
                : ($admin->hospital ? 'Admin Hôpital: ' . $admin->hospital->name : 'Hôpital #' . $admin->hospital_id);

            return [
                $admin->id,
                $admin->name,
                $admin->email,
                $admin->phone ?? 'N/A',
                $admin->role,
                $type,
            ];
        });

        $this->table($headers, $rows);

        $this->newLine();
        $this->comment('Note sécurité : Les mots de passe sont hachés et chiffrés en base.');
        if (!$resetPassword) {
            $this->comment('Pour définir un mot de passe connu (ex: Password123!) pour vos tests :');
            $this->info('php artisan edoctor:list-superadmins --reset-password=Password123!');
        }

        return self::SUCCESS;
    }
}
