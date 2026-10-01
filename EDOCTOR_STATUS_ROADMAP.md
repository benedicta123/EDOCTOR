# 🩺 eDoctor — État d'Avancement & Roadmap du Projet

> **Dernière mise à jour :** Septembre 2026  
> **Architecture globale :** API Backend Laravel (PHP 8.2+ / PostgreSQL) + Application Mobile Flutter (Android / iOS / Web).

---

## 📊 1. Vue d'Ensemble des Composants

| Composant | Technologie | Rôle Principal | Statut Actuel |
| :--- | :--- | :--- | :--- |
| **Backend API** | Laravel 11 / Sanctum / PostgreSQL | Cœur métier, authentification multi-rôles, téléconsultations, ordonnances, officines, pharmacie, dispatch des soins | **Opérationnel & Structuré** |
| **Application Mobile** | Flutter 3.x / Material 3 | Interface Patient tout-en-un (Téléconsultation, commandes pharmacie, soins infirmiers, dossier médical, profil) | **Interfaces Clés Implémentées** |
| **Données & Écosystème** | Seeder & Migrations | Écosystème certifié (CHU de Démo, 2 médecins, 2 infirmières, 3 pharmacies partenaires avec stocks) | **Inséré & Vérifié** |

---

## ✅ 2. Ce Qui Est Déjà Implémenté & Structuré

### 🖥️ A. Backend API (`edoctor-api`)

1. **Authentification & Gestion des Rôles (Sanctum) :**
   - Inscription dédiée pour les patients (`POST /api/patients/register` et `/api/register`).
   - Connexion et déconnexion sécurisées par tokens (`POST /api/login`, `POST /api/logout`).
   - Profil utilisateur connecté (`GET /api/me`).
   - Rôles pris en charge : `patient`, `doctor`, `nurse`, `pharmacist`, `admin`.

2. **Établissements Hospitaliers & Certification :**
   - Enregistrement d'un hôpital partenaire (`POST /api/hospitals/register`).
   - Workflow d'approbation administrative : Hôpitaux en attente, validation officielle ou rejet (`/api/admin/hospitals/...`).
   - Gestion du personnel médical rattaché à l'hôpital (`POST /api/my-hospital/doctors`, `POST /api/my-hospital/nurses`).

3. **Disponibilité en Temps Réel (Heartbeat) :**
   - Système de battement de cœur (`POST /api/heartbeat`) mettant à jour le champ `last_seen_at`.
   - Endpoint des médecins disponibles (`GET /api/doctors/available`) filtrant sur les hôpitaux certifiés.

4. **Téléconsultations & Messagerie Sécurisée :**
   - Création, acceptation, démarrage et clôture de consultations (`/api/consultations/...`).
   - Messagerie textuelle instantanée liée à la session médicale (`/api/consultations/{id}/messages`).

5. **Ordonnances & Prescriptions Médicales :**
   - Émission d'ordonnances dématérialisées avec posologies et durées (`/api/prescriptions`).
   - Liaison directe avec les consultations et les dossiers patients.

6. **Officines Pharmaceutiques & Stocks :**
   - Gestion des pharmacies partenaires (`/api/pharmacies`).
   - Catalogue des médicaments et suivi des stocks officinaux (`/api/pharmacies/{id}/stocks`).
   - Recherche de disponibilité à proximité (`/api/medications/{id}/availability`).

7. **Commandes en Pharmacie & Livraison :**
   - Passage de commande avec ordonnance ou médicaments sans prescription (`/api/orders`).
   - Gestion des statuts de préparation et de retrait (`mark-ready`, `mark-collected`).
   - Module de livraison express avec assignation d'un coursier (`/api/deliveries`).

8. **Soins Infirmiers à Domicile :**
   - Création d'une visite infirmière issue d'une ordonnance (`/api/prescriptions/{id}/nurse-visit`).
   - Workflow d'assignation, acceptation et validation d'intervention (`/api/nurse-visits`).

9. **Dossier Médical Patient :**
   - Consultation du dossier médical complet (`GET /api/patients/{patient}/dossier`).

---

### 📱 B. Application Mobile (`edoctor_mobile`)

1. **Parcours d'Inscription Patient (Multi-étapes) :**
   - **Étape 1 (`RegisterStep1Screen`) :** Données d'état civil, email, mot de passe sécurisé, téléphone avec indicatif pays (+228 / +225).
   - **Étape 2 (`RegisterStep2Screen`) :** Date de naissance, adresse de résidence, antécédents médicaux déclarés.

2. **Écran d'Accueil (`HomeScreen`) :**
   - Salutation personnalisée et badge d'état.
   - Bouton principal grand format : *« Consulter un médecin »*.
   - **Grille Bento (4 accès rapides) :**
     - 🛍️ *Mes commandes*
     - 📋 *Mes prescriptions*
     - 📜 *Historique médical*
     - 🩹 *Soins à domicile*
   - Carte d'activité clinique récente avec bouton d'accès direct à l'ordonnance en cours.
   - Barre de navigation inférieure (`PatientBottomNav`) avec 4 onglets : Accueil, Médecins, Dossier, Profil.

3. **Menu « Médecins » (`FindDoctorScreen`) :**
   - Liste des médecins disponibles alimentée par l'API et la base de données :
     - **Dr. Paul Koffi** (Médecine Générale • CHU de Démo).
     - **Dr. Amina Touré** (Pédiatrie • CHU de Démo).
   - Fiches médecins détaillées : Note, avis, langues parlées, statut en ligne.
   - Modal de confirmation et lancement de téléconsultation vidéo.

4. **Interface « Mes Commandes » (`OrdersScreen`) :**
   - Suivi complet des commandes pharmaceutiques par statut (Toutes, En cours, Livrées).
   - Identification de la pharmacie partenaire, adresse, téléphone, détail des médicaments et prix en FCFA.
   - Modal de détails avec appel direct de l'officine et consultation du reçu.

5. **Interface « Mes Prescriptions » (`PrescriptionsScreen`) :**
   - Consultation des ordonnances actives et archivées.
   - Diagnostic médical, médicaments prescrits, posologie exacte et instructions du médecin.
   - Action directe *« Commander en pharmacie »* permettant de choisir parmi les 3 officines partenaires :
     - *Grande Pharmacie Centrale de Démo*
     - *Pharmacie de la Paix & Espérance*
     - *Pharmacie Sainte-Marie*
   - Bouton d'accès direct pour planifier un soin infirmier lié à la prescription.

6. **Interface « Historique Médical » (`MedicalHistoryScreen`) :**
   - Synthèse clinique : Antécédents médicaux chroniques, allergies documentées, groupe sanguin (O+).
   - Suivi des constantes vitales (Tension artérielle, rythme cardiaque, poids & IMC).
   - Chronologie interactive des événements de santé (téléconsultations, ordonnances, bilans sanguins).
   - Exportation sécurisée du carnet de santé en PDF.

7. **Interface « Soins à Domicile » (`HomeCareScreen`) :**
   - Mise en avant du personnel soignant rattaché au CHU de Démo (**Infirmier Paul Yao**, **Infirmière Sarah Koné**).
   - Catalogue des prestations infirmières (Injections & Perfusions, Pansements de plaies, Prélèvements sanguins, Surveillance des constantes).
   - Suivi des visites programmées avec statut et bouton d'appel direct de l'infirmier.
   - Formulaire modal de demande de visite avec choix du soin, date/heure et adresse.

8. **Menu « Dossier Médical » (`PatientDossierScreen`) :**
   - Référence du dossier national eDoctor.
   - Mesures biologiques et profil de santé.
   - Antécédents chirurgicaux et médicaux chroniques.
   - Allergies majeures et contre-indications.
   - Médecin référent et contact d'urgence (personne de confiance).

9. **Menu « Profil » (`PatientProfileScreen`) :**
   - Données personnelles du compte patient.
   - Établissements et praticiens favoris.
   - Gestion des notifications (rappels de prises de médicaments, suivi de commande par SMS).
   - Numéros d'urgence médicale rapide (SAMU 118 / 15) et assistance eDoctor.
   - Déconnexion sécurisée réinitialisant la session (`StorageService.clearSession`).

---

## 🗄️ 3. Données de Test Actuellement Présentes en Base

* **Mot de passe commun pour tous les comptes de test :** `Password123!`
* **Hôpital Partenaire :**
  - *Centre Hospitalier Universitaire de Démo* (ID: 1, Agrément: `AGR-MSHP-2024-042`, statut: `verifie`).
* **Médecins (CHU de Démo) :**
  - `dr.koffi@edoctor.test` — Dr. Paul Koffi (Médecine Générale, ID: 3).
  - `dr.amina@edoctor.test` — Dr. Amina Touré (Pédiatrie, ID: 4).
* **Infirmiers (CHU de Démo) :**
  - `infirmier.paul@edoctor.test` — Infirmier Paul Yao (ID: 5).
  - `infirmiere.sarah@edoctor.test` — Infirmière Sarah Koné (ID: 6).
* **Pharmacies Partenaires (3) :**
  - *Grande Pharmacie Centrale de Démo* (Plateau, ID: 1, Titulaire: Dr. Luc Bernard).
  - *Pharmacie de la Paix & Espérance* (Zone 4, ID: 2, Titulaire: Dr. Fatou Diallo).
  - *Pharmacie Sainte-Marie* (Angré, ID: 3, Titulaire: Dr. Marc Yao).
* **Patients Inscrits :**
  - `benedictehounkanli@gmail.com` — Bénédicta (ID: 1).
  - `patient.jean@edoctor.test` — Jean Dupont (ID: 7).
  - `patiente.marie@edoctor.test` — Marie Kouassi (ID: 8).

---

## 🚀 4. Ce Qui Reste à Implémenter (Prochaines Étapes)

### 🔴 Priorité Haute
1. **Intégration du Flux Vidéo WebRTC :**
   - Remplacement du déclencheur d'appel actuel par un composant WebRTC réel (Agora, Jitsi ou Twilio Video) pour la visioconférence sécurisée entre le patient et le médecin.
2. **Passerelles de Paiement Mobile Money Locales :**
   - Connexion des paiements en ligne pour le règlement des consultations, des médicaments et des soins infirmiers (T-Money, Flooz, Wave, Orange Money, carte bancaire via PayDunya ou CinetPay).
3. **Notifications Push en Temps Réel :**
   - Configuration Firebase Cloud Messaging (FCM) pour notifier le patient lors de la validation d'une ordonnance, de l'arrivée d'un soignant ou de la disponibilité d'une commande.

### 🟡 Priorité Moyenne
4. **Portail Web / Mobile Dédié pour les Médecins :**
   - Interface de téléconsultation avec prise de notes cliniques, rédaction directe d'ordonnance et accès à l'historique du patient.
5. **Espace Pharmacien (Gestion des Commandes & Stocks) :**
   - Interface permettant au pharmacien de scanner une ordonnance, valider la préparation d'un panier et déclencher un coursier.
6. **Espace Infirmier Mobile :**
   - Application pour l'infirmier avec géolocalisation de la tournée, validation des actes et signature électronique.

### 🟢 Priorité Basse / Évolutions
7. **Géolocalisation & Carte Interactive :**
   - Intégration de Flutter Map / Google Maps pour visualiser les pharmacies de garde et suivre le coursier en temps réel.
8. **Dossier Médical Partagé Interopérable (HL7 / FHIR) :**
   - Synchronisation avec les systèmes d'information hospitaliers (SIH).
