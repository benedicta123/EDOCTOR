# 📘 eDoctor — Document Métier & Règles de Gestion (Spécifications Cliniques)

**Projet :** Plateforme Intégrée de Télémédecine & E-Santé eDoctor (Togo Health Direct)  
**Version :** 2.0 — Octobre 2026 (Mise à jour complète de production)  
**Cadre Institutionnel :** République Togolaise — Ministère de la Santé et de l'Hygiène Publique (MSHP)  
**Statut :** Document de Référence Fonctionnelle & Réglementaire  

---

## 1. Vision Générale & Raison d'Être

### 1.1. Contexte Sanitaire & Mission
eDoctor est une plateforme numérique de santé conçue pour désenclaver l'accès aux soins de qualité au Togo et dans la sous-région ouest-africaine. Elle digitalise et sécurise l'intégralité du parcours patient :
1. **La téléconsultation médicale** avec des praticiens certifiés rattachés à des centres hospitaliers homologués (CHU, cliniques agréées).
2. **L'ordonnance numérique sécurisée**, infalsifiable et tracée de son émission à sa dispensation.
3. **La prescription et le suivi d'examens complémentaires & bilans de laboratoire**, permettant l'investigation biologique et radiologique complète avec retour numérique des résultats.
4. **Le circuit officiel du médicament**, en connectant en temps réel les stocks des pharmacies d'officine partenaires pour éradiquer les médicaments contrefaits et éviter les déplacements inutiles.
5. **Les soins infirmiers à domicile**, pour la continuité des soins post-consultation (pansements, injections, perfusions, surveillance des constantes).
6. **Le dossier médical patient unifié**, garantissant l'historique clinique et la continuité de la prise en charge.

```
       ┌────────────────────────────────────────────────────────┐
       │               PLATEFORME CENTRALE EDOCTOR              │
       │       (API Laravel • PostgreSQL • Données HDS)        │
       └───────────────────────────┬────────────────────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  ESPACE PATIENT  │      │ ESPACE PRATICIEN │      │ ESPACE PHARMACIE │
│ (Mobile Flutter) │      │ (Médecin/Hôpital)│      │  (Web & Stocks)  │
└──────────────────┘      └──────────────────┘      └──────────────────┘
```

---

## 2. Typologie des Acteurs & Matrice des Droits (RBAC)

| Rôle | Périmètre d'Action | Interfaces Accessibles | Responsabilité Juridique |
| :--- | :--- | :--- | :--- |
| **Patient (`patient`)** | Titulaire du compte personnel. Consulte les médecins, gère son carnet de santé, télécharge ses ordonnances et bons d'analyses, téléverse ses résultats de laboratoire, passe commande en officine, commande des soins à domicile, dépose des réclamations. | Application Mobile Android / iOS (`edoctor_mobile`). | Responsable de l'exactitude de ses déclarations et antécédents médicaux. |
| **Médecin Praticien (`doctor`)** | Médecin généraliste ou spécialiste inscrit à l'Ordre National des Médecins du Togo (ONMT), rattaché à un établissement hospitalier agréé. | Portail Praticien Web & Tablette (`edoctor_praticient`). | Engage sa responsabilité déontologique et médicale sur chaque acte, prescription médicamenteuse et demande d'analyses. |
| **Pharmacien Titulaire (`pharmacist`)** | Docteur en pharmacie inscrit à l'Ordre des Pharmaciens, gérant d'une officine agréée par le MSHP. | Portail Officine Web & Desktop (`edoctor_pharmacy`). | Responsable du contrôle de l'ordonnance, de la dispensation et de la conformité des stocks. |
| **Personnel Infirmier (`nurse`)** | Infirmier diplômé d'État rattaché à un établissement hospitalier agréé. | Portail Praticien / Module Soins à Domicile. | Responsable de la bonne exécution des actes prescrits et de la saisie des constantes. |
| **Direction Hospitalière (`hospital_admin`)** | Administration de l'hôpital ou de la clinique partenaire. | Dashboard Hôpital (`edoctor_praticient`). | Gestion du personnel soignant, audit d'activité clinique et conventions eDoctor. |
| **Super-Administrateur (`admin`)** | Équipe de gouvernance eDoctor. | Back-Office Central eDoctor (`edoctor_admin`). | Vérification des agréments, validation MSHP, traitement des réclamations, modération légale et supervision financière. |

---

## 3. Règles de Gestion Métier (Business Rules)

### 3.1. Règle RG-01 : Agrément & Certification Préalable des Structures
* **Principe :** Aucun médecin, infirmier ou pharmacien ne peut exercer sur la plateforme sans rattachement à une structure formellement vérifiée.
* **Procédure d'audit :** 
  - Les hôpitaux doivent fournir leur arrêté ministériel d'ouverture, numéro d'enregistrement MSHP et identifiant fiscal.
  - Les pharmacies doivent fournir leur licence d'exploitation d'officine, le numéro d'inscription à l'Ordre du titulaire et leur localisation géographique précise.
  - Tout compte créé demeure en statut `"en_attente"` tant que le Super-Administrateur eDoctor n'a pas validé les pièces justificatives dans le portail `edoctor_admin`.

### 3.2. Règle RG-02 : Disponibilité & Détection en Direct (Heartbeat)
* Un praticien est considéré comme **« Disponible pour consultation immédiate »** si et seulement si :
  1. Son compte est actif et rattaché à un établissement validé.
  2. Son commutateur de présence est activé sur *"En ligne"*.
  3. L'application émet un signal de présence périodique (`POST /api/heartbeat`) avec un `last_seen_at` inférieur à 3 minutes.
* Dès qu'une consultation démarre, le statut passe automatiquement à **« En consultation »** et le médecin est masqué de la file d'attente immédiate.

### 3.3. Règle RG-03 : Cycle de Vie Sécurisé de la Téléconsultation
Le cycle d'une consultation médicale suit un état d'automate strict :
```
[ demandée ] ──► [ en_attente ] ──► [ en_cours ] ──► [ terminée ]
                       │                   │
                       ▼                   ▼
                  [ refusée ]         [ annulée ]
```
1. **Émission de la demande :** Le patient formule sa demande avec motif de consultation.
2. **Prise en charge & Alerte sonore :** Le praticien reçoit une alerte prioritaire avec sonnerie d'appel vidéo en temps réel, consulte le dossier médical partagé du patient et valide le démarrage.
3. **Session clinique :** Téléconsultation audio/vidéo chiffrée, doublée d'un fil de messagerie médicale horodatée.
4. **Numérotation normalisée internationale :** Chaque consultation se voit attribuer une référence unique et inviolable formatée comme suit : `CNS-[AAMM]-[HÔPITAL]-[4CHARS]` (ex: `CNS-2610-CHU-A8K2`).
5. **Clôture atomique :** La consultation ne peut être clôturée (`terminée`) que si le praticien saisit un **diagnostic médical documenté**.

### 3.4. Règle RG-04 : Règle d'Or de l'Ordonnance Numérique
* **Aucune création prématurée :** Lors de la rédaction, tant que le praticien n'a pas appuyé sur le bouton définitif **« Terminer la consultation »**, aucun médicament ni ordonnance n'est enregistré dans la base officielle ni visible sur le compte du patient. Les informations saisies restent en brouillon sécurisé.
* **Intégrité de l'ordonnance émise :** Une fois validée :
  - Elle porte une référence unique (ex: `ORD-2026-XXXX`).
  - Elle mentionne impérativement : identité et âge du patient, médecin prescripteur, hôpital de rattachement, diagnostic initial, liste exhaustive des spécialités avec dosage, forme galénique, posologie quotidienne et durée de traitement.
  - Elle intègre un **cachet numérique horodaté** et un **QR Code d'authentification**.
  - Elle devient **immuable** (non modifiable après signature numérique).

### 3.5. Règle RG-05 : Verrouillage Médico-Légal & Délais d'Annulation
* **Délai strict de grâce :** Une ordonnance ne peut être annulée par le médecin que dans une fenêtre maximale de **5 minutes** suivant son émission (pour correction d'erreur matérielle immédiate). Passé ce délai de 5 minutes, l'annulation est irréversiblement bloquée par le système (`403 Forbidden`).
* **Clôture automatique d'expiration :** Toute consultation active dépassant une durée de **2 heures** sans clôture manuelle est automatiquement terminée par le système (`closeExpiredConsultations()`) pour éviter les sessions orphelines et libérer le praticien.

### 3.6. Règle RG-06 : Circuit des Examens Complémentaires & Bilans de Laboratoire
1. **Prescription médicale :** Le médecin peut prescrire un ou plusieurs examens biologiques ou d'imagerie médicale (NFS, Goutte Épaisse Paludisme, Test Widal, Glycémie à jeun, Bilan rénal, Échographie, Radiographie) lors d'une consultation.
2. **Identification standardisée :** Chaque demande de bilan reçoit un code unique formaté : `LAB-[AAMM]-[HÔPITAL]-[4CHARS]` (ex: `LAB-2610-CHU-T9M4`).
3. **Consignes cliniques :** Précision obligatoire des indications médicales, de la consigne *"À jeun"* et du caractère d'urgence (*Normal* vs *Urgent*).
4. **Bon d'examen certifié :** Génération d'un document PDF officiel comportant le QR Code de certification de l'acte pour le laboratoire d'analyses.
5. **Téléversement des résultats :** Le patient téléverse la photo ou le fichier PDF des résultats remis par le laboratoire directement dans l'application mobile.
6. **Revue médicale :** Le praticien consulte les résultats via un visualiseur à zoom haute résolution et consigne ses conclusions cliniques définitives dans le dossier du patient.

### 3.7. Règle RG-07 : Circuit Officinal & Dispensation du Médicament
1. **Choix souverain du patient :** Le patient choisit librement parmi les pharmacies d'officine partenaires disposant des stocks requis.
2. **Modes de délivrance :**
   - **Retrait en officine (Click & Collect) :** Gratuit, le patient retire sa commande au comptoir de la pharmacie après présentation de son ordonnance numérique ou de son QR code.
   - **Livraison sécurisée :** Acheminement sous pli scellé respectant les conditions de conservation des médicaments.
3. **Décrémentation des stocks :** Chaque validation de dispensation (`mark-ready` ou `mark-collected`) décrémente automatiquement le stock physique en base de données avec verrou transactionnel (`lockForUpdate`).
4. **Verrouillage anti-réutilisation :** Une ordonnance délivrée est marquée comme *"dispensée"* pour interdire toute double délivrance frauduleuse.

### 3.8. Règle RG-08 : Gestion des Litiges & Réclamations Usagers
* Tout usager (patient ou praticien) dispose d'un droit de réclamation en cas d'incident technique, litige financier ou manquement professionnel.
* Le dossier est assigné au Super-Administrateur eDoctor avec suivi d'état transparent : `en_attente` ──► `en_cours` ──► `resolu` / `rejete`.

---

## 4. Secret Médical, Traçabilité & Conformité Juridique

### 4.1. Protection des Données Personnelles de Santé
* Conformément aux lois togolaises et aux directives de l'UEMOA/CEDEAO relatives à la cybercriminalité et à la protection des données nominatives :
  - Toutes les communications sont chiffrées en transit via **TLS 1.3 / HTTPS**.
  - Les identifiants, tokens et données cliniques sont stockés sous partition sécurisée avec chiffrement au repos.
  - Le patient détient la propriété exclusive de ses données de santé et peut à tout moment exporter son dossier médical complet en PDF certifié.

### 4.2. Piste d'Audit Médical (Audit Trail)
* Tout accès ou tentative d'accès à un dossier médical fait l'objet d'une journalisation immuable dans la table `audit_logs` :
  - Identifiant de l'utilisateur ayant consulté ou modifié le dossier.
  - Horodatage certifié (date, heure, seconde).
  - Adresse IP et type d'appareil.
  - Nature de l'opération (lecture de diagnostic, émission d'ordonnance, consultation d'analyses, dispensation officinale).

---

## 5. Règles Financières & Tarification Officielle (Directives DG Octobre 2026)

### 5.1. Politique Tripartite : Zéro Prélèvement Partenaires & Frais de Service Fixes
* **Pour les Hôpitaux & Cliniques :**
  - **Liberté tarifaire totale :** Chaque établissement fixe librement son tarif de téléconsultation (ex: 2 500 FCFA, 5 000 FCFA, etc.).
  - **0% de prélèvement :** L'hôpital perçoit **100% de son tarif** de consultation sans aucune retenue.
  - **Frais de service eDoctor (600 FCFA) :** Facturés en sus au patient pour la plateforme, la visio chiffrée, le dossier médical et l'absorption intégrale des frais de transaction Mobile Money (T-Money, Flooz).
* **Pour les Pharmacies d'Officine :**
  - **0% de prélèvement sur les médicaments :** L'officine perçoit **100% du prix officiel** des médicaments vendus.
  - **Frais de mise en relation de stock (150 FCFA) :** Facturés au patient lors de la commande pour la géolocalisation de l'officine de garde et la garantie de stock en direct.
* **Pour la Livraison à Domicile par Coursier :**
  - **Forfait de base : 500 FCFA** incluant les **2 premiers kilomètres**.
  - **150 FCFA par kilomètre supplémentaire** au-delà des 2 premiers km.
  - Formule : `Frais de livraison = 500 FCFA + [max(0, Distance_km - 2) × 150 FCFA]`.
  - Répartition : ~75% reversés au coursier partenaire et ~25% conservés par eDoctor (coordination logistique).

### 5.2. Tableau de Synthèse des Flux par Transaction

| Prestation | Montant Réglé par le Patient | Part Reversée Hôpital | Part Pharmacie / Coursier | Revenu Net eDoctor |
| :--- | :--- | :--- | :--- | :--- |
| **Téléconsultation (Ex: 3 000 F)** | 3 600 FCFA *(Tarif hôpital + 600 F)* | **3 000 FCFA (100%)** | — | **600 FCFA** *(Frais plateforme & Mobile Money)* |
| **Commande Pharmacie (Retrait)** | Prix Médicaments + 150 F | — | **100% Prix Médicaments** | **150 FCFA** *(Frais recherche stock)* |
| **Livraison Express (Distance 5 km)** | 950 FCFA *(500 F base + 3×150 F)* | — | **700 FCFA** *(Coursier partenaire)* | **250 FCFA** *(Marge coordination)* |
| **Soins Infirmiers à Domicile** | Tarif Hôpital + 600 FCFA | **100% Tarif Soin** | — | **600 FCFA** *(Frais de service)* |

