# 💊 Manuel Utilisateur — Espace Pharmacie & Gestion des Stocks

**Application :** eDoctor Pharmacie (`edoctor_pharmacy`)  
**Cible :** Pharmaciens titulaires, pharmaciens adjoints et préparateurs d'officine  
**Plateforme :** Web, Desktop (PC / Mac), Tablette  
**Version :** 2.0 — Guide Pratique Officinal (Édition Complète Octobre 2026)  
**Langue :** Français  

---

## 1. Introduction & Mission du Portail Pharmacie

Le portail **eDoctor Pharmacie** est l'outil professionnel dédié aux officines partenaires au Togo. Conçu pour intégrer la pharmacie dans la chaîne de soins dématérialisée sous la tutelle du Ministère de la Santé et de l'Hygiène Publique (MSHP), il permet :
- La réception et le traitement des commandes de médicaments issues des ordonnances numériques eDoctor.
- La vérification de l'authenticité des prescriptions médicales par **scan de QR Code infalsifiable**.
- La gestion en temps réel du catalogue et des stocks disponibles avec alertes automatiques de seuil critique.
- **L'importation et l'exportation en masse de l'inventaire** via des fichiers Excel (`.xlsx`) et CSV standardisés compatibles avec vos logiciels de gestion d'officine.
- Le suivi des agréments et de la conformité réglementaire auprès de l'Ordre National des Pharmaciens du Togo (ONPT).

---

## 2. Connexion & Identification de l'Officine

1. Connectez-vous avec vos identifiants d'officine (**Email officiel** et **Mot de passe**).
2. **Identification visuelle immédiate :** Dès votre connexion, vos informations réglementaires sont affichées en haut de l'interface :
   - **En-tête supérieur (Header) :** Un badge vert mentionne le **Nom officiel de la pharmacie** et le **Nom du pharmacien titulaire** (*ex: « Grande Pharmacie Centrale • Titulaire : Dr. Luc Bernard »*).
   - **Haut de la barre latérale :** L'intitulé certifié de votre officine s'affiche avec votre statut de vérification.
   - **Bannière d'accueil du Dashboard :** Une carte rappelle le nom de l'établissement, son adresse certifiée (*ex: Boulevard du 13 Janvier, Lomé*) et le badge d'officine partenaire homologuée.

---

## 3. Le Tableau de Bord Officine (Dashboard)

Le tableau de bord centralise en un coup d'œil l'activité de dispensation et l'état de votre stock :

```
┌────────────────────────────────────────────────────────────────────────┐
│  🟢 Grande Pharmacie Centrale • Titulaire : Dr. Luc Bernard           │
├────────────────────────────────────────────────────────────────────────┤
│  INDICATEURS CLÉS :                                                    │
│  ┌───────────────────┐  ┌───────────────────┐  ┌────────────────────┐  │
│  │ ⏳ 3               │  │ 🛍️ 8              │  │ ⚠️ 4               │  │
│  │ À préparer        │  │ Prêtes au retrait │  │ Alertes stocks     │  │
│  │ (En attente)      │  │ (Attente patient) │  │ (Seuil critique)   │  │
│  └───────────────────┘  └───────────────────┘  └────────────────────┘  │
│  ┌───────────────────┐  ┌───────────────────┐                          │
│  │ 💊 120            │  │ 💰 450 000 F      │                          │
│  │ Références actives│  │ Valeur du stock   │                          │
│  └───────────────────┘  └───────────────────┘                          │
├────────────────────────────────────────────────────────────────────────┤
│  RÉPARTITION :                                                         │
│  [ Commandes récentes à préparer ]       [ Alertes stocks critiques ]  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Traitement des Commandes & Dispensation Sécurisée

### 4.1. Réception d'une nouvelle commande
1. Rendez-vous dans le menu **« Commandes »**.
2. Filtrez par statut : **Toutes**, **En attente**, **Prêtes**, ou **Récupérées**.
3. Chaque commande affiche la référence (*ex: #CMD-104*), le nom du patient, la date et le montant total en FCFA.

### 4.2. Authentification de l'ordonnance par QR Code & Contrôle pharmaceutique
1. Cliquez sur la commande pour ouvrir la fiche détaillée.
2. **Vérification infalsifiable :**
   - Scannez le **QR Code** présent sur l'ordonnance du patient (ou saisissez le code `ORD-...`).
   - Le système vérifie en temps réel le hash cryptographique sur les serveurs eDoctor et confirme que l'ordonnance n'a pas déjà été délivrée ailleurs.
3. Vérifiez les éléments cliniques :
   - Identité et âge du patient.
   - Médecin prescripteur et hôpital homologué.
   - Diagnostic clinique posé.
   - Spécialités, formes, dosages et posologies.
   - Mode de délivrance choisi : **Retrait au comptoir (Click & Collect)** ou **Livraison sécurisée**.

### 4.3. Préparation & Décrémentation automatique des stocks
* **Étape 1 : Marquer comme prête :**
  - Une fois les boîtes de médicaments préparées, cliquez sur **« Marquer comme prête »**.
  - Le patient reçoit instantanément une notification l'informant que sa commande est prête.
* **Étape 2 : Remise de la commande :**
  - Lorsque le patient (ou le coursier) se présente, cliquez sur **« Valider la remise (Récupérée) »**.
  - La commande est archivée avec succès et les quantités de médicaments correspondantes sont **automatiquement décrémentées** de votre inventaire en base de données avec verrouillage transactionnel anti-erreur.

---

## 5. Gestion des Stocks : Import & Export Excel (.xlsx) et CSV

Pour éviter la saisie manuelle fastidieuse, eDoctor propose un module complet de gestion d'inventaire en masse :

```
[ Modèle Excel / CSV ]    [ 📥 Exporter l'inventaire ]    [ 📤 Importer un fichier ]
```

### 5.1. Télécharger le Modèle type
1. Dans le menu **« Stocks »**, cliquez sur **« Modèle type »**.
2. Téléchargez au choix la version **Microsoft Excel (.xlsx)** ou **CSV**.
3. **Structure des colonnes prises en charge :**
   ```csv
   nom_medicament;dosage;forme;quantite;prix_fcfa;sur_ordonnance
   Paracétamol;500mg;Comprimé;150;500;non
   Amoxicilline;1g;Gélule;40;2500;oui
   Artéméther / Luméfantrine;20/120mg;Comprimé;80;1800;non
   ```

### 5.2. Exporter l'Inventaire Réel de l'Officine
1. Cliquez sur le bouton **« Exporter l'inventaire »**.
2. Choisissez le format : **Excel (.xlsx)** ou **CSV**.
3. **Avantages pour votre comptabilité :**
   - Calcul automatique de la **Valeur Totale en stock (FCFA)** pour chaque référence (*Quantité × Prix unitaire*).
   - Encodage parfait compatible avec tous les logiciels officinaux du Togo (WinPharma, PharmaGest, etc.).
   - Mention du statut de stock (*En stock / Seuil faible / Rupture*).

### 5.3. Importer un Fichier de Stocks (Mise à jour en 1 clic)
1. Cliquez sur le bouton **« Importer un fichier »**.
2. Glissez-déposez ou sélectionnez votre fichier `.xlsx` ou `.csv`.
3. L'application vérifie instantanément le fichier et affiche le nombre de lignes valides détectées.
4. Cliquez sur **« Lancer l'importation »**.
5. En quelques secondes, les stocks et prix existants sont mis à jour et les nouvelles références sont créées.

---

## 6. Alertes de Stock Critique & Réapprovisionnement

Pour prévenir les ruptures imprévues sur les molécules vitales :
- **Badge Vert (En stock) :** Quantité supérieure au seuil d'alerte (> 10 boîtes).
- **Badge Orange (Stock faible) :** Quantité inférieure ou égale à 10 boîtes. Un avertissement visuel apparaît sur le tableau de bord.
- **Badge Rouge (Rupture) :** Quantité à zéro. Le médicament est automatiquement masqué des résultats de recherche des patients pour éviter les commandes non honorables.

---

## 7. Agréments Réglementaires & Support Officine

Dans l'onglet **« Officine »** :
- Retrouvez les informations de votre licence d'officine validée par le MSHP.
- Contactez le support technique prioritaire eDoctor pour l'assistance logistique ou les litiges de livraison.
