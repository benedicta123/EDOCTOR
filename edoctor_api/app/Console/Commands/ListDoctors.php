<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class ListDoctors extends Command
{
    protected $signature = 'edoctor:list-doctors {--reset-password= : Réinitialise le mot de passe de tous les médecins avec cette valeur}';
    protected $description = 'Affiche la liste de tous les médecins (nom, email, spécialité, hôpital, statut)';

    public function handle(): int
    {
        $doctors = User::where('role', 'doctor')->with('hospital')->get();

        if ($doctors->isEmpty()) {
            $this->warn('Aucun médecin trouvé dans la base de données.');
            return self::SUCCESS;
        }

        $resetPassword = $this->option('reset-password');
        if ($resetPassword) {
            $hashed = Hash::make($resetPassword);
            foreach ($doctors as $doctor) {
                $doctor->password = $hashed;
                $doctor->save();
            }
            $this->info("✓ Le mot de passe de tous les médecins a été réinitialisé à : {$resetPassword}");
            $this->newLine();
        }

        $headers = ['ID', 'Nom Médecin', 'Email', 'Téléphone', 'Spécialité', 'Hôpital', 'Disponibilité'];
        $rows = $doctors->map(function ($doc) {
            return [
                $doc->id,
                $doc->name,
                $doc->email,
                $doc->phone ?? 'N/A',
                $doc->specialty ?? 'Médecine Générale',
                $doc->hospital ? $doc->hospital->name : 'Indépendant',
                $doc->availability_status ?? 'Disponible',
            ];
        });

        $this->table($headers, $rows);

        $this->newLine();
        $this->comment('Note sécurité : Les mots de passe sont hachés et chiffrés en base.');
        if (!$resetPassword) {
            $this->comment('Pour définir un mot de passe connu (ex: Password123!) pour vos tests :');
            $this->info('php artisan edoctor:list-doctors --reset-password=Password123!');
        }

        return self::SUCCESS;
    }
}
