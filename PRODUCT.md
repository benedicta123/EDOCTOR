# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Patients au Togo (francophones, indicatif +228), sur téléphone Android. Ils se connectent, retrouvent consultations, ordonnances, commandes pharmacie et soins à domicile.

## Product Purpose

eDoctor (Togo Health Direct) : téléconsultation, pharmacie, soins à domicile, prescriptions et dossier patient. Succès = un patient se connecte à l'API Laravel locale et accède à ses soins sans friction.

## Positioning

Plateforme médicale certifiée ancrée à Lomé, Togo : parcours patient complet (médecin, ordonnance, commande, domicile, dossier) adossé à une API Laravel locale.

## Operating Context

App Flutter `edoctor_mobile`, API Laravel `edoctor_api` servie en dev sur `http://192.168.1.214:8000/api` (`php artisan serve --host=0.0.0.0`). Dev physique Android via ADB, même Wi-Fi PC + téléphone. Français uniquement.

## Capabilities and Constraints

Fonctionnalités confirmées : splash avec routage token, inscription 2 étapes, login, accueil, recherche médecin, consultations, prescriptions, commandes, historique médical, soins à domicile, dossier patient, profil + logout. Contrainte : garder fonctions, navigation et textes métier inchangés pendant le redesign.

## Brand Commitments

Nom eDoctor, logo `assets/images/logo.png`, vert officiel #529927 + bleu nuit #132A45, français. Référence MedConnect (header vague, carte blanche, hiérarchie compacte) comme inspiration structurelle uniquement, jamais copiée, teintée vert eDoctor. Interdit : emoji 👋 et tout sticker/jeu de mot autour de la main.

## Evidence on Hand

Écrans : `edoctor_mobile/lib/features/splash/splash_screen.dart`, `features/auth/login_screen.dart`, `features/auth/register_step1_screen.dart`, `features/auth/register_step2_screen.dart`, `features/home/home_screen.dart`, `features/doctors/`, `features/prescriptions/`, `features/orders/`, `features/medical_history/`, `features/home_care/`, `features/dossier/`, `features/profile/`. Thème : `core/theme/app_theme.dart`, `core/constants/app_colors.dart`, widgets `app_logo.dart`, `custom_button.dart`, `custom_text_field.dart`.

## Product Principles

1. Le soin d'abord : chaque écran mène à une action médicale concrète.
2. Confiance sobre : esthétique propre, lisible, sans décor superflu.
3. Français simple : libellés d'action et erreurs avec récupération.
4. Continuité du parcours : auth, médecin, ordonnance, commande et dossier restent liés.
