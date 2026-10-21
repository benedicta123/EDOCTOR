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

- [x] **[P0] Sécurisation des Téléconsultations : Statuts Médecin & Annulation Automatique 20 min**
  - [x] Commutateur de statut médical rapide sur le dashboard médecin ([`doctor_dashboard.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_praticient/lib/features/doctor/doctor_dashboard.dart)) : *« Disponible »*, *« Au bloc opératoire »*, *« Indisponible »*.
  - [x] Verrouillage automatique : le praticien passe immédiatement à *« En consultation »* dès l'ouverture d'un appel avec blocage des nouveaux appels.
  - [x] Blocage préventif côté patient ([`doctor_card.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_mobile/lib/features/doctors/widgets/doctor_card.dart)) : bouton « Consulter maintenant » grisé et désactivé avec mention explicite *« Médecin au bloc opératoire »* ou *« Médecin actuellement indisponible »*.
  - [x] Verrouillage de sécurité backend ([`ConsultationController::store`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/ConsultationController.php)) : rejet immédiat avec HTTP 422 si tentative de paiement sur un médecin occupé/au bloc.
  - [x] Annulation automatique après 20 minutes d'attente ([`Consultation::cancelUnansweredConsultations()`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Models/Consultation.php)) : destruction immédiate du séquestre d'honoraires et notification au patient et au praticien.
  - [x] Salle d'attente patient ([`consultation_screen.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_mobile/lib/features/doctors/consultation_screen.dart)) avec bandeau de compte à rebours 20 minutes et dialogue d'orientation immédiate : choix d'un autre confrère disponible ou demande de remboursement Mobile Money sous 24h.
  - [x] Demande systématique d'activation du statut « Disponible » au praticien dès qu'il clique sur « Terminer et transmettre » lors de la clôture de la consultation ([`consultation_detail_screen.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_praticient/lib/features/doctor/consultation_detail_screen.dart)) avec options de bascule vers *« Disponible »*, *« Au bloc »* ou *« Indisponible »*.

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

## 💳 3. Passerelles de Paiement, Portefeuilles & Monétisation (T-Money, Flooz, CB)

- [x] **[P0] Intégration de la Passerelle Mobile Money FedaPay & Sécurisation**
  - [x] Intégration du SDK et service de paiement FedaPay ([`FedaPayService.php`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Services/FedaPayService.php)).
  - [x] Contrôleur de paiement et webhooks avec validation cryptographique HMAC (`FEDAPAY_WEBHOOK_SECRET`) et rate limiting de 60 req/min ([`FedaPayPaymentController.php`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/FedaPayPaymentController.php)).
  - [x] Verrouillage strict interdisant les paiements simulés en environnement de production (`APP_ENV=production`).
  - [x] Moteur de calcul du split économique tripartite dans [`MonetizationService.php`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Services/MonetizationService.php) (100% honoraire à l'hôpital/médecin + 10% eDoctor, 100% médicament à l'officine + 150 FCFA recherche stock, barème kilométrique coursier).

- [x] **[P1] Module Portefeuilles Virtuels (Wallets) & Reversements Praticiens / Pharmacies**
  - [x] **Architecture Base de Données & Modèles :**
    - [x] Migration exécutée `2026_10_19_000001_create_wallets_and_payouts_tables` créant les tables `wallets`, `wallet_transactions` et `payout_requests`.
    - [x] Modèle [`Wallet`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Models/Wallet.php) polymorphique (`User`, `Hospital`, `Pharmacy`) avec solde disponible (`balance`), solde sous séquestre (`pending_balance`) et opérations transactionnelles (`credit()`, `hold()`, `release()`, `cancelHold()`, `debit()`).
    - [x] Modèle [`WalletTransaction`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Models/WalletTransaction.php) pour le journal d'audit comptable inaltérable.
    - [x] Modèle [`PayoutRequest`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Models/PayoutRequest.php) pour le suivi des demandes de virement Mobile Money / Banque.
    - [x] Relations polymorphiques `wallet()` et helper `getOrCreateWallet()` ajoutés sur `User`, `Hospital` et `Pharmacy`.
  - [x] **Raccordement Automatique des Flux Financiers (Escrow ➔ Balance) :**
    - [x] Lors du paiement de consultation : mise en séquestre automatique de la part hôpital/médecin via `$wallet->hold()` ([`Consultation::markAsPaid`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Models/Consultation.php)).
    - [x] Lors de la clôture de consultation avec diagnostic : libération automatique du séquestre vers le solde disponible via `$wallet->release()` ([`ConsultationController::end`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/ConsultationController.php)).
    - [x] Lors de l'annulation d'une consultation payée : libération/annulation du séquestre via `$wallet->cancelHold()` ([`ConsultationController::cancel`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/ConsultationController.php)).
    - [x] Lors de la remise de commande de pharmacie avec code secret OTP 4 chiffres : validation du code, horodatage `collected_at` et crédit automatique du solde de l'officine via `$wallet->credit()` ([`OrderController::markCollected`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/OrderController.php)).
    - [x] Raccordement des livraisons à domicile ([`DeliveryController::markDelivered`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/DeliveryController.php)) : confirmation sécurisée par le patient ou par la pharmacie avec code secret, et crédit automatique du portefeuille de l'officine.
    - [x] Masquage anti-fraude du `pickup_code` aux pharmaciens dans les réponses API (seul le patient le détient).
  - [x] **Contrôleur API du Portefeuille ([`WalletController.php`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/WalletController.php)) :**
    - [x] `GET /api/wallet/my-wallet` : consultation du solde en temps réel et des coordonnées de retrait.
    - [x] `GET /api/wallet/transactions` : historique paginé des mouvements avec filtres (date, type).
    - [x] `POST /api/wallet/payout-request` : soumission d'une demande de retrait vers T-Money ou Moov Flooz avec débit immédiat du disponible.
    - [x] `PUT /api/wallet/payout-account` : enregistrement du numéro et canal de retrait par défaut.
  - [x] **Administration & Traitement des Reversements Super-Admin ([`AdminWalletController.php`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/AdminWalletController.php)) :**
    - [x] `GET /api/admin/wallets` : vue d'ensemble consolidée des soldes de tous les partenaires.
    - [x] `GET /api/admin/payout-requests` : liste des demandes de reversement en attente avec filtres.
    - [x] `POST /api/admin/payout-requests/{id}/approve` : approbation et exécution du décaissement avec référence de virement.
    - [x] `POST /api/admin/payout-requests/{id}/reject` : rejet motivé avec recrédit automatique immédiat du solde du partenaire.
  - [x] **Interfaces Frontend (Flutter Web & Mobile) :**
    - [x] Écran « Mon Portefeuille & Retraits » dans l'application Praticien / Hôpital ([`edoctor_praticient`](file:///c:/Users/belou/Documents/edoctor/edoctor_praticient)) :
      - [x] Dashboard Bento : solde disponible (retirable), honoraires sous séquestre (en attente de clôture avec diagnostic), total des recettes ([`praticien_wallet_screen.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_praticient/lib/features/wallet/praticien_wallet_screen.dart)).
      - [x] Indicateurs de performance personnelle pour les médecins libéraux (volume de consultations réalisées, CA généré).
      - [x] Modal de demande de retrait d'honoraires vers T-Money, Moov Flooz ou Virement bancaire national avec contrôle de solde.
      - [x] Configuration des coordonnées de virement par défaut et historique complet des transactions.
      - [x] Intégration dans le menu latéral et le drawer ([`praticien_nav.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_praticient/lib/core/widgets/praticien_nav.dart)) pour médecins et hôpitaux.
      - [x] Raccourcis directs dans les tableaux de bord médecin ([`doctor_dashboard.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_praticient/lib/features/doctor/doctor_dashboard.dart)) et hôpital ([`hospital_dashboard.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_praticient/lib/features/hospital/hospital_dashboard.dart)).
    - [x] Écran « Caisse & Versements » dans le portail Pharmacie ([`edoctor_pharmacy`](file:///c:/Users/belou/Documents/edoctor/edoctor_pharmacy)) :
      - [x] Dialogue sécurisé de remise au comptoir avec saisie du code secret à 4 chiffres du patient et crédit immédiat du portefeuille ([`orders_screen.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_pharmacy/lib/features/orders/orders_screen.dart)).
      - [x] Prise en charge des livraisons à domicile (assignation coursier & confirmation par code secret avec crédit portefeuille).
      - [x] Dashboard Bento de Caisse : solde disponible, solde sous séquestre, total cumulé ([`pharmacy_wallet_screen.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_pharmacy/lib/features/wallet/pharmacy_wallet_screen.dart)).
      - [x] Formulaire de demande de virement Mobile Money (T-Money, Flooz, Banque) avec vérification de solde.
      - [x] Configuration des coordonnées de versement par défaut et historique complet des transactions.
      - [x] Intégration dans le menu de navigation ([`pharmacy_shell.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_pharmacy/lib/core/widgets/pharmacy_shell.dart)) et raccourci dans le tableau de bord ([`pharmacy_dashboard.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_pharmacy/lib/features/dashboard/pharmacy_dashboard.dart)).
    - [x] Écran « Trésorerie & Payouts » dans le portail Super-Admin ([`edoctor_admin`](file:///c:/Users/belou/Documents/edoctor/edoctor_admin)) :
      - [x] Dashboard de liquidité écosystème : volume total sous séquestre, total des soldes retirables partenaires, payouts validés & en attente ([`finance_payouts_screen.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_admin/lib/features/finance/finance_payouts_screen.dart)).
      - [x] Modal d'approbation et décaissement avec référence d'opération Mobile Money / virement bancaire.
      - [x] Modal de rejet motivé avec recrédit automatique immédiat du solde disponible du partenaire.
      - [x] Onglet explorateur de l'ensemble des portefeuilles actifs (médecins, hôpitaux, pharmacies).
      - [x] Intégration dans la barre latérale du shell Super-Admin ([`admin_shell.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_admin/lib/core/widgets/admin_shell.dart)).

---

## 🩹 4. Module Soins Infirmiers à Domicile

- [x] **[P1] Workflow d'affectation et de validation de visite (`edoctor_praticient` & `edoctor_api`)**
  - [x] Lors de la réservation d'un soin par le patient depuis son ordonnance, transmission automatique à l'hôpital ([`prescriptions_screen.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_mobile/lib/features/prescriptions/prescriptions_screen.dart)).
  - [x] Écran d'affectation de l'hôpital pour assigner un infirmier disponible ([`nurse_visits_screen.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_praticient/lib/features/hospital/nurse_visits_screen.dart)).
  - [x] Espace mobile dédié à l'infirmier avec tournées du jour, statut de mission et contact patient ([`nurse_dashboard.dart`](file:///c:/Users/belou/Documents/edoctor/edoctor_praticient/lib/features/nurse/nurse_dashboard.dart)).
  - [x] Permettre à l'infirmier d'accepter l'intervention (« En route » avec notification du patient) ou de la décliner.

- [x] **[P1] Fiche de transmission et compte-rendu infirmier**
  - [x] Validation des actes réalisés au chevet du patient (pansement stérile, injection IM/SC, perfusion, soins de sonde/stomie, soins d'hygiène).
  - [x] Saisie des constantes vitales au lit du malade (tension artérielle, glycémie capillaire, température, pouls) directement enregistrées en base (`nurse_visits`) et intégrées au dossier médical ([`PatientDossierController.php`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/PatientDossierController.php)).

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

- [x] **[P0] Configuration de la Passerelle Transactionnelle Brevo (API REST v3 & Envoi des OTP Réels)**
  - [x] Clé API Brevo intégrée et opérationnelle (`BREVO_API_KEY` / `xkeysib-...`).
  - [x] Expéditeur officiel vérifié : `contacts@ewaregroup.org` (Nom d'affichage : *"eDoctor Sécurité"*).
  - [x] Service dédié ultra-robuste [`BrevoMailService`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Services/BrevoMailService.php) connecté à l'API v3 `/v3/smtp/email`.
  - [x] Acheminement certifié opérationnel pour les 3 flux critiques :
    - Double Authentification 2FA Médecin & Admin ([`AuthController`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/AuthController.php)).
    - Vérification d'adresse email à l'inscription ([`EmailVerificationController`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/EmailVerificationController.php)).
    - Réinitialisation sécurisée de mot de passe oublié ([`PasswordResetController`](file:///c:/Users/belou/Documents/edoctor/edoctor_api/app/Http/Controllers/Api/PasswordResetController.php)).
    - Alerte de sécurité en cas de tentative d'intrusion / verrouillage temporaire de compte.

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
