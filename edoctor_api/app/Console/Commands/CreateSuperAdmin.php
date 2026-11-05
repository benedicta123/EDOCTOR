<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class CreateSuperAdmin extends Command
{
    protected $signature = 'edoctor:create-superadmin 
                            {name? : Nom complet du Super-Administrateur} 
                            {email? : Adresse email} 
                            {password? : Mot de passe} 
                            {--phone= : Numéro de téléphone}';

    protected $description = 'Crée un compte Super-Administrateur National pour la plateforme eDoctor';

    public function handle(): int
    {
        $name = $this->argument('name') ?: $this->ask('Nom complet du Super-Administrateur');
        $email = $this->argument('email') ?: $this->ask('Adresse email');

        if (User::where('email', $email)->exists()) {
            $this->error("Un utilisateur avec l'email '{$email}' existe déjà en base de données.");
            return self::FAILURE;
        }

        $password = $this->argument('password');
        if (empty($password)) {
            $password = $this->secret('Mot de passe');
        }

        if (strlen($password) < 8) {
            $this->error('Le mot de passe doit comporter au moins 8 caractères.');
            return self::FAILURE;
        }

        $phone = $this->option('phone') ?: $this->ask('Numéro de téléphone (optionnel)', null);

        $superAdmin = User::create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make($password),
            'role' => 'superadmin',
            'hospital_id' => null,
            'phone' => $phone,
            'email_verified_at' => now(),
        ]);

        $this->newLine();
        $this->info("✓ Super-Administrateur National créé avec succès !");
        $this->table(
            ['ID', 'Nom', 'Email', 'Rôle', 'Téléphone'],
            [[
                $superAdmin->id,
                $superAdmin->name,
                $superAdmin->email,
                $superAdmin->role,
                $superAdmin->phone ?? 'N/A',
            ]]
        );
        $this->newLine();
        $this->comment("Ce compte peut maintenant se connecter à l'interface d'administration eDoctor.");

        return self::SUCCESS;
    }
}
