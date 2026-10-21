# 📚 Documentation Métier & Manuels Utilisateurs — eDoctor

Bienvenue dans le centre de documentation officiel de l'écosystème de santé numérique **eDoctor** (Togo Health Direct).

Ce dossier regroupe les spécifications cliniques, les règles de gestion métier et les manuels utilisateurs détaillés pour l'ensemble des acteurs de la plateforme. Tous les documents sont synchronisés et disponibles aux formats Markdown (`.md`) et Microsoft Word professionnel (`.docx`).

---

## 📑 Sommaire des Documents Officiels (Édition Complète Octobre 2026)

| N° | Document | Cible & Destinataires | Description |
| :---: | :--- | :--- | :--- |
| **01** | [**Document Métier & Règles de Gestion**](01_DOCUMENT_METIER_ET_REGLES_DE_GESTION.md) | Direction, Équipe Produit, Développeurs, Régulateurs MSHP | Architecture quadripartite, matrice RBAC, règles cliniques (RG-01 à RG-10), double authentification (2FA OTP via Brevo), sécurité anti-brute force, intégrité webhooks FedaPay, bilans de laboratoire, secret médical et modèle économique. |
| **02** | [**Manuel Utilisateur — Espace Patient**](02_MANUEL_UTILISATEUR_PATIENT.md) | Patients, Grand public, Support client | Inscription avec validation email OTP, double authentification (2FA), téléconsultation vidéo, ordonnances certifiées QR Code, bons de bilans labo (`LAB-...`), téléversement de résultats, commandes officines et litiges. |
| **03** | [**Manuel Utilisateur — Praticien & Hôpital**](03_MANUEL_UTILISATEUR_PRATICIEN_ET_HOPITAL.md) | Médecins, Cadres CHU, Super-Admin | Connexion 2FA, alerte sonore d'appel entrant, prescription sécurisée (filtrage géolocalisé des stocks), bilans de laboratoire avec visualiseur HD zoom, verrou de 5 min et articulation avec le portail Super-Admin `edoctor_admin`. |
| **04** | [**Manuel Utilisateur — Pharmacie & Officine**](04_MANUEL_UTILISATEUR_PHARMACIE_ET_OFFICINE.md) | Pharmaciens titulaires, Adjoints, Préparateurs | Connexion 2FA, vérification d'ordonnances par QR Code infalsifiable, dispensation sécurisée, décrémentation automatique des stocks, import / export Excel (.xlsx) et CSV, gestion des seuils critiques et agréments. |

---

## 🏛️ Cadre, Sécurité & Normes de Référence

- **Territoire d'application prioritaire :** République Togolaise (Grand Lomé & Régions) et sous-région ouest-africaine.
- **Autorités de tutelle :** Ministère de la Santé et de l'Hygiène Publique (MSHP).
- **Ordres professionnels :** Ordre National des Médecins du Togo (ONMT) & Ordre National des Pharmaciens du Togo (ONPT).
- **Monnaie officielle :** Franc CFA (XOF / FCFA).
- **Conformité technique & Sécurité :** Chiffrement TLS 1.3 / HTTPS, Double Authentification 2FA (Brevo REST API v3), verrouillage anti-force brute (10 tentatives / 30 min), Webhooks financiers FedaPay protégés par signature HMAC et limitation de débit (60 req/min).
- **Stack Technologique :** API Laravel 11 (PHP 8.4) avec PostgreSQL, Applications Mobiles et Web Flutter 3, Portail Super-Admin Docker Nginx SPA déployé sur Dokploy.
