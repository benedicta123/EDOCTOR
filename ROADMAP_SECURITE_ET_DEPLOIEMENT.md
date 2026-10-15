# Feuille de Route & Tâches de Sécurisation eDoctor

Ce document consigne les fonctionnalités de sécurité, d'authentification et de déploiement à intégrer suite à la validation de la démo par le Directeur Général.

---

## 1. Sécurisation des Accès & Authentification OTP
 
+### Tâche 0 : Configuration de la Passerelle SMTP Transactionnelle Brevo (Option A retenue)
+* **Priorité :** 🔴 P0 - Critique (Nécessaire pour l'envoi réel des emails d'OTP, 2FA et alertes de sécurité)
+* **Coût / Dépendance :** Gratuit (Plan Brevo Free : 300 emails/jour offerts, aucun frais d'activation)
+* **Paramétrage attendu dans `edoctor_api/.env` :**
+  ```env
+  MAIL_MAILER=smtp
+  MAIL_HOST=smtp-relay.brevo.com
+  MAIL_PORT=587
+  MAIL_USERNAME=<email_du_compte_brevo>
+  MAIL_PASSWORD=<cle_smtp_generee_sur_brevo>
+  MAIL_ENCRYPTION=tls
+  MAIL_FROM_ADDRESS=securite@edoctor.tg
+  MAIL_FROM_NAME="eDoctor Sécurité"
+  ```
+* **Validation :**
+  - Vider le cache de config : `php artisan config:clear`
+  - Déclencher une demande d'OTP ou 2FA et valider la bonne réception en boîte de réception.
+
 ### Tâche 1 : Réinitialisation de mot de passe par Email ("Mot de passe oublié")
 * **Priorité :** 🔴 Haute (Indispensable avant ouverture publique)
 * **Coût / Dépendance :** Gratuit (Passerelle SMTP Brevo / Resend)
 * **Périmètre technique :**
   - **Backend Laravel :** Endpoints `POST /api/forgot-password` et `POST /api/reset-password` avec génération d'un code OTP à 6 chiffres valable 15 minutes.
   - **Mobile Patient (`edoctor_mobile`) :** Ajout du lien *"Mot de passe oublié ?"* sur l'écran de connexion (`LoginScreen`), modal de saisie de l'email, saisie du code OTP reçu, et définition du nouveau mot de passe.
   - **Portails Web :** Intégration sur les pages de connexion des espaces Médecin, Pharmacie et Administration.

### Tâche 2 : Vérification d'Email à l'Inscription
* **Priorité :** 🔴 Haute (Qualité des comptes & lutte anti-spam)
* **Coût / Dépendance :** Gratuit (Passerelle SMTP Brevo / Resend)
* **Périmètre technique :**
  - **Backend Laravel :** Marqueur `email_verified_at` et génération d'un code OTP de vérification lors du `register`.
  - **Mobile Patient (`edoctor_mobile`) :** Écran de confirmation de l'adresse email post-inscription (optionnellement non-bloquant avec bandeau de rappel pour ne pas interrompre l'expérience utilisateur).

### Tâche 3 : Double Authentification (2FA) pour Praticiens & Pharmaciens
* **Priorité :** 🟡 Moyenne (Sécurité des données de santé HDS)
* **Coût / Dépendance :** Gratuit (Google Authenticator / TOTP ou OTP Email)
* **Périmètre technique :**
  - **Backend Laravel :** Implémentation TOTP (RFC 6238) ou envoi de code par email lors de toute nouvelle connexion praticien/admin.
  - **Portails Web (`edoctor_praticient`, `edoctor_pharmacy`) :** Écran de saisie du second facteur à la connexion, QR code de liaison dans le profil praticien.

### Tâche 4 : Vérification du Numéro de Téléphone par SMS OTP
* **Priorité :** 🟢 Étape Production Grand Public (Payante)
* **Coût / Dépendance :** Payant (Abonnement passerelle SMS agréée Afrique de l'Ouest / Togo : Termii, Twilio ou passerelle locale Togocom/Moov).
* **Périmètre technique :**
  - **Backend Laravel :** Service d'expédition SMS, table `phone_verifications`, limitation de fréquence (*rate-limiting* anti-abus).
  - **Mobile Patient (`edoctor_mobile`) :** Vérification du numéro de mobile lors de la commande de médicaments en pharmacie ou de la première consultation.

---

## 2. Hébergement & Déploiement Cloud (Dokploy)

### Tâche 5 : Déploiement Web du Portail Praticien (`edoctor_praticient`)
* **Priorité :** 🔴 Haute (Complément indispensable pour la démo médecin en direct)
* **Périmètre technique :**
  - Compilation Flutter Web : `flutter build web --release`
  - Conteneur Nginx optimisé avec gestion du routage SPA / HTML5 History
  - Déploiement Dokploy sous le domaine `https://praticien.edoctor.ewaregroup.org` (SSL Let's Encrypt automatique).

### Tâche 6 : Déploiement des Portails Pharmacie & Administration
* **Périmètre technique :**
  - Déploiement des interfaces de gestion officine (`edoctor_pharmacy`) et supervision centrale (`edoctor_admin`).
