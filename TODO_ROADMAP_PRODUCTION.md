# 📋 eDoctor — Master To-Do List & Feuille de Route Production

> **Projet :** Écosystème eDoctor (Togo Health Direct)  
> **Composants :** `edoctor_mobile` (Patient), `edoctor_praticient` (Médecin & Hôpital), `edoctor_pharmacy` (Pharmacie & Stocks), `edoctor_api` (Backend Laravel).  
> **Suivi d'avancement global :** 65% complété  
> **Légende des priorités :** 
> - 🔴 **[P0 - Critique]** : Indispensable pour le parcours médical et commercial de base.
> - 🟡 **[P1 - Majeur]** : Essentiel pour l'expérience utilisateur et l'exploitation quotidienne.
> - 🟢 **[P2 - Confort]** : Optimisations avancées, passage à l'échelle et finitions.

---

## 🩺 1. Flux Téléconsultation & Vidéo Temps Réel (Patient ↔ Médecin)

- [x] **[P0] Switch de disponibilité en direct du Médecin (`edoctor_praticient`)**
  - [x] Ajouter un commutateur *"En ligne / Prêt à consulter"* sur le dashboard praticien.
  - [x] Déclencher périodiquement l'appel heartbeat (`POST /api/heartbeat`) pour maintenir le praticien dans la liste des médecins disponibles.
  - [x] Mettre à jour automatiquement le statut en *"Occupé"* dès qu'une consultation démarre.

- [x] **[P0] Alerte d'appel entrant en temps réel pour le Praticien (`edoctor_praticient`)**
  - [x] Afficher un modal d'alerte sonore et visuelle dès qu'un patient clique sur *"Consulter maintenant"*.
  - [x] Proposer les actions immédiates : *"Accepter la consultation"* ou *"Refuser / Reporter"*.

- [x] **[P0] Stabilisation du flux Vidéo JaaS / WebRTC (`edoctor_mobile` & `edoctor_praticient`)**
  - [x] Valider la communication vidéo bidirectionnelle fluide entre smartphone Android et PC/Tablette.
  - [x] Ajouter les contrôles en séance : coupure micro, coupure caméra, bascule caméra frontale/arrière.
  - [x] Gérer élégamment la reconnexion automatique en cas de micro-coupure de la connexion 4G/Wi-Fi.

- [x] **[P0] Règles Médico-Légales, Déontologie & Ergonomie de Consultation**
  - [x] Clôture automatique par le système de toute consultation active dépassant 2 heures (`closeExpiredConsultations()`).
  - [x] Verrouillage médico-légal interdisant l'annulation d'une ordonnance au-delà de 5 minutes après son émission.
  - [x] Enrichissement de la liste des consultations du praticien : affichage du diagnostic posé, médicaments prescrits, durée calculée et date/heure.
  - [x] Filtrage strict du carnet patient : exclusion des consultations annulées ou non honorées du décompte des consultations réalisées.
  - [x] Numérotation structurée pour passage à l'échelle (> 1M utilisateurs) : format standardisé `CNS-[AAMM]-[HÔPITAL]-[4CHARS]` (Option A).

- [x] **[P1] Prescription d'examens complémentaires & bilans de laboratoire**
  - [x] Permettre au médecin d'ajouter une prescription d'analyses (NFS, glycémie, paludisme, échographie) lors de la consultation (`edoctor_praticient`).
  - [x] Code de référence standardisé `LAB-[AAMM]-[HÔPITAL]-[4CHARS]`, indications cliniques, consigne "à jeun" et caractère urgent.
  - [x] Consultation et téléchargement de l'ordonnance d'analyses officielle avec QR Code au format PDF pour le patient (`edoctor_mobile`).
  - [x] Téléversement des résultats d'analyses (photo de la feuille de résultats ou document PDF) par le patient depuis l'application mobile.
  - [x] Consultation, zoom interactif et validation médicale des résultats par le praticien avec conclusions cliniques archivées au dossier médical.

---

## 💊 2. Chaîne Pharmacie, Ordonnances & Délivrance (Patient ↔ Pharmacie)

- [x] **[P0] Tunnel de commande complet pour le Patient (`edoctor_mobile`)**
  - [x] À partir d'une ordonnance émise, permettre au patient de sélectionner une pharmacie partenaire.
  - [x] Vérifier la disponibilité en stock des médicaments prescrits dans l'officine choisie.
  - [x] Proposer le choix entre **Retrait en officine** (gratuit) et **Livraison à domicile**.
  - [x] En cas de livraison : saisie de l'adresse précise, numéro de contact et calcul des frais de coursier.

- [x] **[P0] Décrémentation automatique des stocks officinaux (`edoctor_pharmacy` & `edoctor_api`)**
  - [x] Lors de la validation de la commande, décrémenter automatiquement la quantité disponible en base avec verrou transactionnel (`lockForUpdate`).
  - [ ] Afficher un avertissement au pharmacien si un produit tombe sous le seuil d'alerte minimum.

- [ ] **[P1] Sécurisation de l'ordonnance par QR Code infalsifiable**
  - [ ] Générer un QR Code unique sur chaque ordonnance PDF imprimée ou partagée.
  - [ ] Permettre au pharmacien de scanner ce QR Code avec son application ou sa webcam pour ouvrir directement la fiche de vérification officielle sur le portail eDoctor.

- [x] **[P1] Importation / Exportation CSV en masse du catalogue de médicaments (`edoctor_pharmacy`)**
  - [x] Rendre fonctionnel le téléversement de fichier CSV/Excel pour charger ou mettre à jour le catalogue de médicaments et les prix d'une pharmacie en un clic.
  - [x] Permettre l'export de l'inventaire actuel pour la comptabilité de l'officine.

---

## 💳 3. Passerelles de Paiement & Monétisation (T-Money, Flooz, Wave, CB)

- [ ] **[P0] Intégration d'un agrégateur Mobile Money (Togo & Sous-région)**
  - [ ] Configurer un compte agrégateur (FedaPay, CinetPay ou PayDunya).
  - [ ] Créer le contrôleur backend de paiement (`/api/payments/initiate`, `/api/payments/webhook`).
  - [ ] Connecter le paiement des téléconsultations dans l'application Patient.
  - [ ] Connecter le paiement des commandes de médicaments et frais de livraison.
  - [ ] Connecter le paiement des soins infirmiers à domicile.

- [ ] **[P1] Gestion du portefeuille et reversements Praticiens / Pharmacies**
  - [ ] Calcul automatique de la commission plateforme eDoctor sur chaque transaction.
  - [ ] Tableau de bord financier dans l'espace Médecin et Pharmacie (solde disponible, historique des versements).
  - [ ] Demande de retrait des gains vers un compte T-Money / Flooz ou virement bancaire.

---

## 🩹 4. Module Soins Infirmiers à Domicile

- [x] **[P1] Workflow d'affectation et de validation de visite (`edoctor_praticient` & `edoctor_api`)**
  - [x] Lors de la réservation d'un soin par le patient, notifier l'hôpital de rattachement pour affecter un infirmier.
  - [x] Permettre à l'infirmier d'accepter l'intervention et de consulter l'adresse et le contact du patient.

- [x] **[P1] Fiche de transmission et compte-rendu infirmier**
  - [x] Permettre à l'infirmier de valider l'acte réalisé (pansement, injection, perfusion).
  - [x] Permettre la saisie des constantes prises à domicile (tension, température, glycémie) directement intégrées au dossier médical du patient.

---

## 🔔 5. Notifications Push & Synchronisation Temps Réel (FCM & WebSockets)

- [ ] **[P0] Configuration Firebase Cloud Messaging (FCM)**
  - [ ] Associer le projet Firebase aux applications Android (`google-services.json`).
  - [ ] Enregistrer les tokens FCM des utilisateurs dans la base (`POST /api/fcm-token`).
  - [ ] Envoyer des notifications push automatiques lors des événements clés :
    - [ ] Patient : *"Le Dr. [Nom] a démarré votre téléconsultation"*
    - [ ] Patient : *"Votre ordonnance est disponible au téléchargement"*
    - [ ] Patient : *"Votre commande #... est prête à la pharmacie"*
    - [ ] Médecin : *"Nouvelle demande de consultation en attente"*
    - [ ] Pharmacien : *"Nouvelle commande d'ordonnance reçue"*

- [ ] **[P1] Intégration de WebSockets (Laravel Reverb / Pusher)**
  - [ ] Éliminer le polling de 5 secondes sur le chat de consultation pour une réception instantanée des messages.
  - [ ] Mettre à jour en direct les statuts des commandes sans rechargement manuel.

---

## 🛡️ 6. Espace Administrateur / Super-Admin & Conformité Réglementaire

- [x] **[P1] Interface Web de Gestion Super-Admin**
  - [x] Module de validation des Hôpitaux partenaires (consultation des pièces d'homologation MSHP, bouton validation/rejet, visualiseur d'actes officiels).
  - [x] Module de validation des Pharmacies partenaires (vérification de la licence d'officine, diplôme du titulaire, certificat de l'Ordre).
  - [x] Vue d'ensemble statistique nationale : nombre de consultations, volume de prescriptions, chiffre d'affaires global.

- [x] **[P2] Gestion des utilisateurs, litiges et modération**
  - [x] Possibilité de suspendre ou réactiver un compte en cas de litige ou d'impayé.
  - [x] Journal de gestion des réclamations usagers (patients/médecins) : formulaire de dépôt, suivi de statut en temps réel et notification de résolution.

---

## 🔒 7. Sécurité, Audit & Protection des Données Médicales

- [ ] **[P0] Traçabilité & Journal d'Audit Médical (Audit Trail)**
  - [ ] Journaliser tout accès à un dossier patient dans la table `audit_logs` (qui a consulté le dossier, date, heure, adresse IP).
  - [ ] Garantir le strict respect du secret médical togolais et de la réglementation sur les données de santé.

- [ ] **[P1] Chiffrement et sécurisation des documents sensibles**
  - [ ] Chiffrement des pièces d'identité et documents médicaux stockés sur le serveur.
  - [ ] Masquage partiel des numéros de téléphone et emails sensibles dans les listes publiques.

---

## 🚀 8. Préparation Production, Mode Hors-Ligne & Déploiement Cloud

- [ ] **[P1] Mode Hors-Ligne (Offline Caching) pour le Patient (`edoctor_mobile`)**
  - [ ] Mise en cache locale du carnet de santé, des constantes et des ordonnances déjà consultées.
  - [ ] Permettre au patient d'accéder à son ordonnance PDF même sans connexion Internet active.

- [ ] **[P0] Configuration et Déploiement Serveur Production**
  - [ ] Conteneurisation Docker (`docker-compose.prod.yml`) pour l'API Laravel, PostgreSQL et Redis.
  - [ ] Mise en place du serveur web Nginx avec certificat SSL HTTPS gratuit (Let's Encrypt / Certbot).
  - [ ] Configuration du stockage cloud sécurisé (Amazon S3 ou MinIO local) pour les ordonnances et photos de profil.
  - [ ] Automatisation des sauvegardes quotidiennes de la base de données PostgreSQL.

- [x] **[P0] Génération des APK / App Bundles finaux pour Android**
  - [x] Configuration réseau clair (`network_security_config.xml`) et liaison IP dynamique du serveur de développement.
  - [x] Compilation de l'APK installable sans dépendance au câble de débogage (`edoctor_mobile_latest.apk`).
