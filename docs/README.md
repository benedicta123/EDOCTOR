# 📚 Documentation Métier & Manuels Utilisateurs — eDoctor

Bienvenue dans le centre de documentation officiel de l'écosystème de santé numérique **eDoctor** (Togo Health Direct).

Ce dossier regroupe les spécifications cliniques, les règles de gestion métier et les manuels utilisateurs détaillés pour l'ensemble des acteurs de la plateforme. Tous les documents sont synchronisés et disponibles aux formats Markdown (`.md`) et Microsoft Word professionnel (`.docx`).

---

## 📑 Sommaire des Documents Officiels (Édition Octobre 2026)

| N° | Document | Cible & Destinataires | Description |
| :---: | :--- | :--- | :--- |
| **01** | [**Document Métier & Règles de Gestion**](01_DOCUMENT_METIER_ET_REGLES_DE_GESTION.md) | Direction, Équipe Produit, Développeurs, Régulateurs MSHP | Architecture générale, rôles RBAC, règles cliniques (RG-01 à RG-08), bilans de laboratoire, verrous médico-légaux, secret médical, audit trail et modèle économique en FCFA. |
| **02** | [**Manuel Utilisateur — Espace Patient**](02_MANUEL_UTILISATEUR_PATIENT.md) | Patients, Grand public, Support client | Inscription 2 étapes, téléconsultation vidéo, ordonnances avec QR code, bilans de laboratoire & examens (`LAB-...`), téléversement de résultats, commandes en officine et litiges. |
| **03** | [**Manuel Utilisateur — Praticien & Hôpital**](03_MANUEL_UTILISATEUR_PRATICIEN_ET_HOPITAL.md) | Médecins généralistes/spécialistes, Cadres CHU & Cliniques | Alerte d'appel entrant avec sonnerie, prescription d'ordonnances et d'analyses de laboratoire, visualiseur de résultats avec zoom, verrou d'annulation 5 min et dossier chronologique unifié. |
| **04** | [**Manuel Utilisateur — Pharmacie & Officine**](04_MANUEL_UTILISATEUR_PHARMACIE_ET_OFFICINE.md) | Pharmaciens titulaires, Adjoints, Préparateurs en pharmacie | Réception des ordonnances, scan QR Code infalsifiable, dispensation, décrémentation des stocks, import / export Excel (.xlsx) et CSV, et alertes de seuil critique. |

---

## 🏛️ Cadre & Normes de Référence

- **Territoire d'application prioritaire :** République Togolaise (Grand Lomé & Régions) et sous-région ouest-africaine.
- **Autorités de tutelle :** Ministère de la Santé et de l'Hygiène Publique (MSHP).
- **Ordres professionnels :** Ordre National des Médecins du Togo (ONMT) & Ordre National des Pharmaciens du Togo (ONPT).
- **Monnaie officielle :** Franc CFA (XOF / FCFA).
- **Conformité technique :** Sécurité HDS, Chiffrement TLS 1.3 / HTTPS, Architecture REST Laravel 11 (PHP 8.4) & Applications Flutter 3.
