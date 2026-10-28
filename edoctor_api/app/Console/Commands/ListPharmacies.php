<?php

namespace App\Console\Commands;

use App\Models\Pharmacy;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class ListPharmacies extends Command
{
    protected $signature = 'edoctor:list-pharmacies {--reset-password= : Réinitialise le mot de passe de tous les pharmaciens titulaires avec cette valeur}';
    protected $description = 'Affiche la liste de toutes les pharmacies partenaires (nom, emails, téléphones, adresse, statut et titulaire)';

    public function handle(): int
    {
        $pharmacies = Pharmacy::with('owner')->get();

        if ($pharmacies->isEmpty()) {
            $this->warn('Aucune pharmacie trouvée dans la base de données.');
            return self::SUCCESS;
        }

        $resetPassword = $this->option('reset-password');
        if ($resetPassword) {
            $hashed = Hash::make($resetPassword);
            $owners = $pharmacies->pluck('owner')->filter();
            foreach ($owners as $owner) {
                $owner->password = $hashed;
                $owner->save();
            }
            $this->info("✓ Le mot de passe de tous les pharmaciens titulaires a été réinitialisé à : {$resetPassword}");
            $this->newLine();
        }

        $headers = [
            'ID',
            'Nom Pharmacie',
            'Email Officine',
            'Téléphone',
            'Adresse',
            'Statut',
            'Titulaire (Nom)',
            'Email Connexion Titulaire',
        ];

        $rows = $pharmacies->map(function ($p) {
            return [
                $p->id,
                $p->name,
                $p->official_email ?? 'N/A',
                $p->phone ?? 'N/A',
                $p->address ?? 'N/A',
                strtoupper($p->status ?? 'EN_ATTENTE'),
                $p->owner ? $p->owner->name : 'Non assigné',
                $p->owner ? $p->owner->email : 'N/A',
            ];
        });

        $this->table($headers, $rows);

        $this->newLine();
        $this->comment('Note sécurité : Les mots de passe sont hachés et chiffrés en base.');
        if (!$resetPassword) {
            $this->comment('Pour définir un mot de passe connu (ex: Password123!) pour vous connecter sur le portail Pharmacie :');
            $this->info('php artisan edoctor:list-pharmacies --reset-password=Password123!');
        }

        return self::SUCCESS;
    }
}
