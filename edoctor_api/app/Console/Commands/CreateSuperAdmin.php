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

    protected $description = 'Crée ou met à jour un compte Super-Administrateur National pour la plateforme eDoctor';

    public function handle(): int
    {
        $name = $this->argument('name') ?: $this->ask('Nom complet du Super-Administrateur');
        $email = $this->argument('email') ?: $this->ask('Adresse email');

        $existingUser = User::where('email', $email)->first();

        if ($existingUser) {
            $this->warn("Un utilisateur avec l'email '{$email}' existe déjà (ID: {$existingUser->id}, Rôle actuel: {$existingUser->role}).");
            if ($this->confirm("Voulez-vous configurer/promouvoir ce compte en Super-Administrateur National ?", true)) {
                $password = $this->argument('password');
                if (empty($password)) {
                    $changePwd = $this->confirm("Voulez-vous modifier son mot de passe ?", false);
                    if ($changePwd) {
                        $password = $this->secret('Nouveau mot de passe');
                    }
                }
                if (!empty($password)) {
                    $existingUser->password = Hash::make($password);
                }
                // Rôle canonique du Super-Admin National dans eDoctor
                $existingUser->role = 'admin';
                $existingUser->hospital_id = null;
                if (!empty($name) && $name !== $existingUser->name) {
                    $existingUser->name = $name;
                }
                $phone = $this->option('phone');
                if ($phone) {
                    $existingUser->phone = $phone;
                }
                $existingUser->email_verified_at = $existingUser->email_verified_at ?? now();
                $existingUser->save();

                $this->newLine();
                $this->info("✓ Compte configuré avec succès en Super-Administrateur National !");
                $this->table(
                    ['ID', 'Nom', 'Email', 'Rôle', 'Téléphone'],
                    [[
                        $existingUser->id,
                        $existingUser->name,
                        $existingUser->email,
                        'admin (Super-Admin National)',
                        $existingUser->phone ?? 'N/A',
                    ]]
                );
                $this->newLine();
                $this->comment("Ce compte peut maintenant se connecter à l'interface d'administration eDoctor.");
                return self::SUCCESS;
            }
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

        // Dans eDoctor, un Super-Administrateur National possède role='admin' et hospital_id=null
        $superAdmin = User::create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make($password),
            'role' => 'admin',
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
                'admin (Super-Admin National)',
                $superAdmin->phone ?? 'N/A',
            ]]
        );
        $this->newLine();
        $this->comment("Ce compte peut maintenant se connecter à l'interface d'administration eDoctor.");

        return self::SUCCESS;
    }
}
