# 🩺 Manuel Utilisateur — Espace Praticien & Établissement Hospitalier

**Application :** eDoctor Praticien (`edoctor_praticient`)  
**Cible :** Médecins généralistes et spécialistes, Administrateurs hospitaliers (CHU, cliniques agréées)  
**Plateforme :** Web, Tablette, PC  
**Version :** 2.0 — Guide Pratique Professionnel (Édition Complète Octobre 2026)  
**Langue :** Français  

---

## 1. Introduction & Présentation du Portail

Le portail **eDoctor Praticien** est l'environnement numérique de travail dédié aux professionnels de santé au Togo. Conçu selon les normes déontologiques du Ministère de la Santé et de l'Hygiène Publique (MSHP) et de l'Ordre National des Médecins du Togo (ONMT), il permet :
- La prise en charge fluide des téléconsultations médicales avec **alerte d'appel entrant en temps réel et sonnerie**.
- La numérotation normalisée internationale de chaque acte (`CNS-AAMM-HOPITAL-XXXX`).
- La prescription assistée et sécurisée d'**ordonnances médicales** avec verrou médico-légal anti-annulation.
- La prescription complète de **bilans de laboratoire et examens complémentaires** (`LAB-AAMM-HOPITAL-XXXX`) avec visualiseur de résultats à zoom interactif.
- La consultation du dossier médical partagé du patient dans un flux chronologique unifié.
- La coordination hospitalière du personnel soignant et des soins infirmiers à domicile.

---

## 2. Connexion, Prise de Service & Détection de Présence

1. Rendez-vous sur l'adresse du portail praticien.
2. Saisissez votre **Email professionnel** et votre **Mot de passe**.
3. Cliquez sur **« Se connecter »**.
4. **Gestion du statut de présence (Heartbeat) :** 
   - Sur votre tableau de bord, activez le commutateur **« En ligne »** lorsque vous êtes prêt à recevoir des patients.
   - Votre application émet automatiquement un signal de présence périodique (`heartbeat`) pour informer les patients de votre disponibilité immédiate.
   - Dès qu'une consultation démarre, votre statut bascule automatiquement sur **« En consultation »** pour éviter d'être interrompu.

---

## 3. Le Tableau de Bord Praticien (Dashboard)

Le tableau de bord est organisé pour vous donner une vision claire et synthétique de votre activité sans surcharge cognitive :

```
┌────────────────────────────────────────────────────────────────────────┐
│  Dr. Paul Koffi — Médecine Générale • CHU Sylvanus     [ Déconnexion ] │
│  Statut : [ 🟢 En ligne / Prêt à consulter ]                           │
├────────────────────────────────────────────────────────────────────────┤
│  INDICATEURS CLÉS D'ACTIVITÉ :                                         │
│  ┌───────────────────┐  ┌───────────────────┐  ┌────────────────────┐  │
│  │ ⏳ 2               │  │ ✅ 48             │  │ 👥 35              │  │
│  │ En attente        │  │ Terminées         │  │ Patients suivis    │  │
│  └───────────────────┘  └───────────────────┘  └────────────────────┘  │
│  ┌───────────────────┐  ┌───────────────────┐                          │
│  │ 📜 45             │  │ 🔬 18             │                          │
│  │ Ordonnances émises│  │ Bilans prescrits  │                          │
│  └───────────────────┘  └───────────────────┘                          │
├────────────────────────────────────────────────────────────────────────┤
│  CONSULTATIONS RÉCENTES :                                              │
│  • Bénédicta H. — CNS-2610-CHU-8F2A — Accès palustre — [ 🖨️ PDF ]      │
│  • Jean Dupont — CNS-2610-CHU-1C9E — Rhinopharyngite — [ 🖨️ PDF ]      │
│  • Marie Kouassi — CNS-2610-CHU-7B4K — Bilan HTA — [ 🔬 Analyses ]    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Alerte d'Appel Entrant & Déroulement de la Téléconsultation

### 4.1. Alerte sonore et visuelle en temps réel (Nouveauté)
Dès qu'un patient clique sur *"Consulter maintenant"* et vous sélectionne :
- Une **sonnerie d'appel médical** retentit sur votre ordinateur ou tablette.
- Un **modal d'appel entrant prioritaire** apparaît au premier plan, affichant :
  - Le nom, l'âge et le quartier du patient.
  - Le motif de consultation déclaré.
  - Deux boutons d'action immédiate :
    - 🟢 **Accepter la consultation :** ouvre immédiatement la salle clinique et coupe la sonnerie.
    - 🔴 **Refuser / Reporter :** notifie poliment le patient et libère la file d'attente.

### 4.2. Séance Vidéo & Messagerie Clinique
* **Appel Vidéo haute définition :** Échangez en direct avec le patient pour l'interrogatoire clinique et l'inspection visuelle.
* **Chat médical temps réel :** Échangez des précisions écrites horodatées (vos messages en vert, ceux du patient en blanc).

### 4.3. Rédaction du Diagnostic & de l'Ordonnance (Règle d'Or Sécurisée)
1. **Saisie du Diagnostic :** Renseignez le diagnostic documenté (champ obligatoire pour clore la séance).
2. **Prescription des médicaments :**
   - Sélectionnez la molécule dans la liste officielle (*ex: Artéméther / Luméfantrine*).
   - Renseignez la forme, le dosage, la posologie quotidienne et la durée.
   - Cliquez sur **« Ajouter à l'ordonnance »**.
3. **Persistance du brouillon :** Vos saisies restent en mémoire tampon tant que la séance n'est pas clôturée. Aucun patient ne peut voir une ordonnance incomplète.
4. **Validation définitive :** Cliquez sur **« Terminer la consultation »**. L'ordonnance officielle chiffrée avec QR Code est émise.

### 4.4. Règles Médico-Légales de Verrouillage & Déontologie
* **Verrou d'annulation (5 minutes) :** En conformité avec les règles déontologiques, une ordonnance émise ne peut être annulée que dans un délai strict de **5 minutes** (correction d'erreur matérielle). Au-delà, l'ordonnance est définitivement verrouillée pour prévenir toute fraude.
* **Clôture automatique d'expiration :** Toute séance active qui dépasserait **2 heures** sans clôture manuelle est automatiquement arrêtée par le système de sécurité hospitalier.

---

## 5. Prescription & Suivi des Examens Complémentaires (Nouveauté Octobre 2026)

Lorsque l'investigation clinique nécessite des examens de biologie médicale ou d'imagerie, vous disposez d'un module intégré accessible directement pendant ou après la séance :

### 5.1. Rédiger une demande de bilans de laboratoire
1. Dans la fiche de consultation, cliquez sur l'onglet **« Examens & Bilans Labo »**.
2. **Sélection rapide par chips prédéfinis :**
   - Cliquez sur les examens fréquents pour les ajouter en 1 clic :
     `[ NFS / Hémogramme ]` `[ Goutte Épaisse & TDR Paludisme ]` `[ Test Widal ]` `[ Glycémie à jeun ]` `[ Bilan Rénal (Créat/Urée) ]` `[ Bilan Hépatique ]` `[ Échographie Abdominale ]` `[ Radiographie Thorax ]`.
   - Vous pouvez également saisir n'importe quel examen personnalisé dans le champ libre.
3. **Consignes et précautions :**
   - Cochez la case **« À jeun impératif »** si nécessaire.
   - Cochez le badge **« Examen Urgent »** pour prioriser le traitement au laboratoire.
   - Renseignez les **indications cliniques** destinées au biologiste ou radiologue.
4. Cliquez sur **« Émettre la prescription d'analyses »**.
   - Le système génère le code officiel `LAB-[AAMM]-[HÔPITAL]-[4CHARS]`.
   - Le patient reçoit immédiatement son bon d'examen officiel en PDF avec QR Code certifié.

### 5.2. Visualiseur & Validation Médicale des Résultats reçus
Dès que le patient téléverse les résultats remis par le laboratoire :
1. Une notification et un badge vert **« Résultats reçus »** apparaissent sur votre dossier.
2. Cliquez sur **« Consulter les résultats »** pour ouvrir le **Visualiseur Haute Résolution** :
   - Inspectez le scan ou la photo du compte-rendu d'analyses avec zoom interactif et panoramique.
3. **Conclusions médicales :**
   - Rédigez votre interprétation clinique dans l'espace **« Conclusions du Médecin »** (ex: *« Taux d'hémoglobine normal à 13.5 g/dL, GE négative, confirmation de l'absence de paludisme »*).
   - Cliquez sur **« Valider la revue médicale »**. Vos conclusions sont définitivement archivées dans le carnet de santé du patient.

---

## 6. Menu « Patients » & Dossier Médical Chronologique

### 6.1. Fiche Patient 360°
Chaque carte de patient présente d'un coup d'œil :
- Identité, âge, numéro de téléphone direct et quartier.
- Antécédents médicaux, groupe sanguin et allergies documentées.
- Nombre total de téléconsultations réalisées.

### 6.2. Flux Chronologique Unique
Dans le dossier du patient, l'ensemble des actes forme une chronologie cohérente :
- Consultation ──► Ordonnance médicale ──► Bilans de laboratoire prescrits ──► Résultats d'analyses reçus et validés.
- Possibilité d'exporter le dossier médical patient complet en PDF en un clic.

---

## 7. Espace Établissement Hospitalier (Direction & Encadrement)

Pour les comptes administrateurs de centres hospitaliers :
1. **Activité Hospitalière :** Statistiques globales de téléconsultations et d'ordonnances émises par l'équipe soignante.
2. **Gestion du Personnel :** Rattachement de nouveaux médecins et infirmiers diplômés d'État.
3. **Coordination des Soins Infirmiers à Domicile :**
   - Consultation des demandes de soins à domicile émises par les patients.
   - Affectation d'un infirmier selon le secteur géographique du Grand Lomé.
   - Suivi de la réalisation des soins et validation des transmissions infirmières.
