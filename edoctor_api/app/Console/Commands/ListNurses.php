<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class ListNurses extends Command
{
    protected $signature = 'edoctor:list-nurses {--reset-password= : Réinitialise le mot de passe de tous les infirmiers avec cette valeur}';
    protected $description = 'Affiche la liste de tous les infirmiers (nom, email, téléphone, hôpital)';

    public function handle(): int
    {
        $nurses = User::where('role', 'nurse')->with('hospital')->get();

        if ($nurses->isEmpty()) {
            $this->warn('Aucun infirmier trouvé dans la base de données.');
            return self::SUCCESS;
        }

        $resetPassword = $this->option('reset-password');
        if ($resetPassword) {
            $hashed = Hash::make($resetPassword);
            foreach ($nurses as $nurse) {
                $nurse->password = $hashed;
                $nurse->save();
            }
            $this->info("✓ Le mot de passe de tous les infirmiers a été réinitialisé à : {$resetPassword}");
            $this->newLine();
        }

        $headers = ['ID', 'Nom', 'Email', 'Téléphone', 'Hôpital', 'Disponibilité'];
        $rows = $nurses->map(function ($nurse) {
            return [
                $nurse->id,
                $nurse->name,
                $nurse->email,
                $nurse->phone ?? 'N/A',
                $nurse->hospital ? $nurse->hospital->name : 'Aucun',
                $nurse->availability_status ?? 'N/A',
            ];
        });

        $this->table($headers, $rows);

        $this->newLine();
        $this->comment('Note sécurité : Les mots de passe sont hachés et illisibles en base.');
        if (!$resetPassword) {
            $this->comment('Pour définir un mot de passe connu pour tous vos tests, lancez :');
            $this->info('php artisan edoctor:list-nurses --reset-password=Password123!');
        }

        return self::SUCCESS;
    }
}
