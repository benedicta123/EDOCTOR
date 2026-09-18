<?php

namespace App\Console\Commands;

use App\Models\Hospital;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class CreateAdmin extends Command
{
    protected $signature = 'edoctor:create-admin';
    protected $description = 'Crée un compte administrateur rattaché à un hôpital (jamais via l\'API publique)';

    public function handle(): int
    {
        $hospitals = Hospital::pluck('name', 'id');

        if ($hospitals->isEmpty()) {
            $this->error('Aucun hôpital en base. Crée-en un d\'abord (via tinker ou un endpoint dédié).');
            return self::FAILURE;
        }

        $name = $this->ask('Nom complet de l\'administrateur');
        $email = $this->ask('Email');
        $password = $this->secret('Mot de passe');

        $hospitalId = $this->choice(
            'Hôpital à administrer',
            $hospitals->toArray(),
            null
        );
        // $this->choice renvoie le libellé choisi, on retrouve l'id correspondant :
        $hospitalId = $hospitals->search($hospitalId);

        $admin = User::create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make($password),
            'role' => 'admin',
            'hospital_id' => $hospitalId,
        ]);

        $this->info("Administrateur créé : {$admin->email} (id {$admin->id}), rattaché à l'hôpital #{$hospitalId}.");

        return self::SUCCESS;
    }
}
