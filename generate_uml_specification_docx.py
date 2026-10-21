import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn
import os

def create_document():
    doc = docx.Document()

    # --- Configuration des marges (2 cm partout) ---
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)
        section.different_first_page_header_footer = True
        
        # En-tête et pied de page
        footer = section.footer
        f_p = footer.paragraphs[0]
        f_p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        f_run = f_p.add_run("eDoctor Togo — Spécification UML & Relations du Modèle Métier")
        f_run.font.name = "Calibri"
        f_run.font.size = Pt(8.5)
        f_run.font.color.rgb = RGBColor(128, 128, 128)

    # --- Couleurs de la charte eDoctor ---
    COLOR_PRIMARY = RGBColor(10, 78, 137)     # Bleu Médical Profond (#0A4E89)
    COLOR_SECONDARY = RGBColor(14, 131, 136)  # Bleu Canard / Saphir (#0E8388)
    COLOR_DARK = RGBColor(33, 37, 41)         # Gris Foncé Texte (#212529)
    COLOR_MUTED = RGBColor(108, 117, 125)     # Gris Secondaire (#6C757D)
    HEX_PRIMARY = "0A4E89"
    HEX_SECONDARY = "0E8388"
    HEX_LIGHT_BG = "F4F7FB"
    HEX_BORDER = "D0DCE5"

    def set_cell_background(cell, fill_hex):
        shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
        cell._tc.get_or_add_tcPr().append(shading)

    def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
        tcPr = cell._tc.get_or_add_tcPr()
        tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
        tcPr.append(tcMar)

    # --- Titre Principal ---
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(10)
    title_p.paragraph_format.space_after = Pt(2)
    title_run = title_p.add_run("ÉCOSYSTÈME MÉDICAL eDOCTOR")
    title_run.font.name = "Calibri"
    title_run.font.size = Pt(13)
    title_run.font.bold = True
    title_run.font.color.rgb = COLOR_SECONDARY

    h1_p = doc.add_paragraph()
    h1_p.paragraph_format.space_before = Pt(2)
    h1_p.paragraph_format.space_after = Pt(8)
    h1_run = h1_p.add_run("Spécification Détaillée du Diagramme de Classes UML :\nRelations Métier & Cardinalités du Modèle de Données")
    h1_run.font.name = "Calibri"
    h1_run.font.size = Pt(20)
    h1_run.font.bold = True
    h1_run.font.color.rgb = COLOR_PRIMARY

    meta_p = doc.add_paragraph()
    meta_p.paragraph_format.space_before = Pt(0)
    meta_p.paragraph_format.space_after = Pt(16)
    m_run = meta_p.add_run("Référentiel Technique & Conception Logicielle | Architecture Backend Laravel & Modèles Eloquent | Togo Health Direct")
    m_run.font.name = "Calibri"
    m_run.font.size = Pt(9.5)
    m_run.font.italic = True
    m_run.font.color.rgb = COLOR_MUTED

    # --- Boîte d'Introduction ---
    intro_table = doc.add_table(rows=1, cols=1)
    intro_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    intro_cell = intro_table.rows[0].cells[0]
    set_cell_background(intro_cell, HEX_LIGHT_BG)
    set_cell_margins(intro_cell, top=140, bottom=140, left=180, right=180)
    intro_p = intro_cell.paragraphs[0]
    intro_p.paragraph_format.space_before = Pt(2)
    intro_p.paragraph_format.space_after = Pt(2)
    i_run = intro_p.add_run("Présentation et Objet du Document :\n")
    i_run.font.name = "Calibri"
    i_run.font.size = Pt(10)
    i_run.font.bold = True
    i_run.font.color.rgb = COLOR_PRIMARY
    i_body = intro_p.add_run(
        "Ce document consigne l'analyse exhaustive des relations et associations du diagramme de classes de la plateforme eDoctor. "
        "Il explicite pour chaque lien : sa nature conceptuelle (association, composition, agrégation), "
        "ses cardinalités bidirectionnelles (notation UML standard : 1, 0..1, 1..*, 0..*), la clé étrangère sous-jacente en base de données, "
        "la règle médico-légale ou fonctionnelle associée, ainsi que son comportement en cascade (suppression, intégrité référentielle, chiffrement)."
    )
    i_body.font.name = "Calibri"
    i_body.font.size = Pt(9.5)
    i_body.font.color.rgb = COLOR_DARK

    doc.add_paragraph().paragraph_format.space_after = Pt(10)

    # --- Données des Relations par Module ---
    modules_data = [
        {
            "module_num": "1",
            "module_title": "Module Gouvernance, Utilisateurs & Établissements Sanitaires",
            "module_desc": "Structure institutionnelle, gestion des rôles (Patient, Médecin, Pharmacien, Infirmier, Administrateur) et accréditation des structures physiques.",
            "relations": [
                {
                    "title": "Relation 1.1 : Hospital (1) ──── (0..*) User (Praticiens & Personnel de santé)",
                    "nature": "Association bidirectionnelle avec clé étrangère optionnelle",
                    "cardinality": "Hospital [1] <─── emploie / rattache ───> [0..*] User",
                    "fk": "users.hospital_id (nullable)",
                    "sens_1": "Un Établissement Hospitalier emploie zéro ou plusieurs utilisateurs (médecins spécialistes, infirmiers à domicile, administrateurs d'hôpital).",
                    "sens_2": "Un utilisateur peut être rattaché à un seul hôpital physique (médecin hospitalier, infirmier), ou à aucun (un patient est un citoyen autonome, un super-administrateur d'État n'a pas de rattachement hospitalier unique).",
                    "regle": "Règle de Conformité MSHP : Tout médecin exerçant la téléconsultation sous l'égide d'une structure hospitalière doit voir son compte validé par l'administrateur de cet hôpital.",
                    "cascade": "Intégrité restrictive (ON DELETE SET NULL / RESTRICT) : la suppression d'un hôpital n'efface pas les fiches d'identité des soignants mais neutralise leurs prérogatives de consultation sous cet établissement."
                },
                {
                    "title": "Relation 1.2 : Pharmacy (1) ──── (1) User (Pharmacien Titulaire / Owner)",
                    "nature": "Association 1-à-1 forte (Responsabilité légale officinale)",
                    "cardinality": "Pharmacy [1] <─── appartient à / dirigée par ───> [1] User",
                    "fk": "pharmacies.owner_id (unique, not null)",
                    "sens_1": "Une officine de pharmacie agréée appartient obligatoirement à un et un seul Pharmacien Titulaire, responsable déontologique et légal inscrit à l'Ordre National des Pharmaciens du Togo.",
                    "sens_2": "Un utilisateur ayant le rôle 'pharmacist' est titulaire exclusif d'une seule officine déclarée dans le système eDoctor.",
                    "regle": "Règle Déontologique : La délivrance de médicaments et la tenue du stock officinal engagent la responsabilité personnelle du Pharmacien titulaire de la licence d'officine.",
                    "cascade": "ON DELETE RESTRICT : Une pharmacie ne peut être supprimée si son titulaire est actif, garantissant la traçabilité des délivrances d'ordonnances antérieures."
                }
            ]
        },
        {
            "module_num": "2",
            "module_title": "Module Téléconsultation & Messagerie Clinique Instantanée",
            "module_desc": "Rencontre synchrone patient-médecin, vidéo temps réel, recueil des symptômes, diagnostic et traçabilité des échanges.",
            "relations": [
                {
                    "title": "Relation 2.1 : User / Patient (1) ──── (0..*) Consultation",
                    "nature": "Association 1-à-Plusieurs (Dossier Médical Patient)",
                    "cardinality": "User [1] (Patient) <─── sollicite ───> [0..*] Consultation",
                    "fk": "consultations.patient_id (not null)",
                    "sens_1": "Un patient peut ouvrir zéro ou plusieurs téléconsultations au cours de sa vie médicale sur l'application mobile.",
                    "sens_2": "Chaque téléconsultation est impérativement liée à un patient unique dûment identifié.",
                    "regle": "Clôture automatique : Une consultation non honorée ou expirée au-delà de 2 heures est automatiquement clôturée par le démon système (closeExpiredConsultations).",
                    "cascade": "ON DELETE RESTRICT : Interdiction absolue d'effacer une consultation active ou archivée afin de préserver l'historique médico-légal du carnet de santé."
                },
                {
                    "title": "Relation 2.2 : User / Doctor (1) ──── (0..*) Consultation",
                    "nature": "Association 1-à-Plusieurs (Actes médicaux praticien)",
                    "cardinality": "User [1] (Doctor) <─── prend en charge ───> [0..*] Consultation",
                    "fk": "consultations.doctor_id (not null)",
                    "sens_1": "Un médecin prend en charge zéro consultation (s'il est nouveau ou indisponible) ou plusieurs centaines de téléconsultations au fil de sa pratique.",
                    "sens_2": "Chaque consultation est dirigée par un seul praticien responsable du diagnostic posé.",
                    "regle": "Règle de visibilité : Le praticien ne voit apparaître la demande de consultation dans sa file d'attente qu'une fois le paiement préalable certifié par FedaPay.",
                    "cascade": "ON DELETE RESTRICT : Les actes médicaux réalisés par le praticien demeurent scellés dans les archives nationales."
                },
                {
                    "title": "Relation 2.3 : Consultation (1) ──── (0..*) Message",
                    "nature": "Composition Forte (Fil de discussion de la consultation)",
                    "cardinality": "Consultation [1] <─── contient ───> [0..*] Message",
                    "fk": "messages.consultation_id (not null)",
                    "sens_1": "Une consultation dispose d'un fil de discussion comprenant zéro message (consultation exclusivement visio/vocale) ou plusieurs messages textuels et notes.",
                    "sens_2": "Chaque message clinique appartient strictement et irrévocablement à une consultation médicale donnée.",
                    "regle": "Chiffrement et Sécurité : Le contenu de chaque message est chiffré au repos (AES-256) en base de données. Aucun message ne peut être émis une fois la consultation marquée comme 'terminee' ou 'annulee'.",
                    "cascade": "ON DELETE CASCADE : Si une consultation de test est purgée, ses messages associés sont supprimés en cascade."
                },
                {
                    "title": "Relation 2.4 : User / Sender (1) ──── (0..*) Message",
                    "nature": "Association 1-à-Plusieurs (Émetteur du message)",
                    "cardinality": "User [1] <─── rédige / expédie ───> [0..*] Message",
                    "fk": "messages.sender_id (not null)",
                    "sens_1": "Un utilisateur (patient ou médecin) expédie de multiples messages au cours d'une séance.",
                    "sens_2": "Chaque message clinique est signé numériquement par son émetteur exact pour empêcher toute usurpation d'identité médicale.",
                    "regle": "Contrôle d'accès : Seuls les participants officiels (patient ou médecin assigné) ont le droit de poster ou lire les messages de la séance.",
                    "cascade": "ON DELETE RESTRICT sur l'expéditeur."
                }
            ]
        },
        {
            "module_num": "3",
            "module_title": "Module Prescriptions Médicales & Catalogue Pharmaceutique",
            "module_desc": "Émission d'ordonnances dématérialisées, lignes de posologie quantifiées, verrouillage médico-légal et catalogue des molécules.",
            "relations": [
                {
                    "title": "Relation 3.1 : Consultation (1) ──── (0..1) Prescription",
                    "nature": "Association Un-à-Un optionnelle (Aboutissement clinique)",
                    "cardinality": "Consultation [1] <─── délivre ───> [0..1] Prescription",
                    "fk": "prescriptions.consultation_id (not null, relation logique 1..1)",
                    "sens_1": "Une téléconsultation donne lieu soit à aucune ordonnance (simple conseil médical, bilan négatif), soit à une seule ordonnance officielle.",
                    "sens_2": "Une ordonnance médicale découle obligatoirement d'une téléconsultation réelle préalable ayant posé un diagnostic vérifié.",
                    "regle": "Verrou de 5 minutes : L'annulation d'une ordonnance n'est autorisée par le praticien que dans un délai strict de 5 minutes après sa création. Passé ce délai, elle est scellée pour des raisons médico-légales.",
                    "cascade": "ON DELETE RESTRICT : Préservation légale du document de prescription."
                },
                {
                    "title": "Relation 3.2 : Prescription (1) ──── (1..*) PrescriptionItem",
                    "nature": "Composition Forte (Lignes de traitement / Posologie)",
                    "cardinality": "Prescription [1] <─── détaille ───> [1..*] PrescriptionItem",
                    "fk": "prescription_items.prescription_id (not null)",
                    "sens_1": "Une ordonnance valide contient obligatoirement au moins une ligne de médicament (1..*). Une ordonnance vide est rejetée par le backend.",
                    "sens_2": "Chaque ligne de posologie appartient exclusivement à l'ordonnance qui l'a émise.",
                    "regle": "Chiffrement Posologique : La colonne dosage_instructions (ex: '1 comprimé matin et soir pendant 5 jours') est chiffrée au repos pour préserver le secret médical.",
                    "cascade": "ON DELETE CASCADE : La suppression d'un brouillon d'ordonnance emporte ses lignes de posologie."
                },
                {
                    "title": "Relation 3.3 : Medication (1) ──── (0..*) PrescriptionItem",
                    "nature": "Association de Référence Catalogue (Nomenclature nationale)",
                    "cardinality": "Medication [1] <─── prescrit dans ───> [0..*] PrescriptionItem",
                    "fk": "prescription_items.medication_id (not null)",
                    "sens_1": "Un médicament du dictionnaire peut n'avoir jamais été prescrit (0) ou figurer sur des milliers de lignes de prescriptions (0..*).",
                    "sens_2": "Une ligne d'ordonnance référence un et un seul médicament homologué présent dans le catalogue eDoctor.",
                    "regle": "Conformité d'officine : Le drapeau requires_prescription conditionne l'obligation légale de fournir une ordonnance lors de l'achat en pharmacie.",
                    "cascade": "ON DELETE RESTRICT : Interdiction formelle de supprimer une molécule du catalogue si elle figure dans l'historique d'une ordonnance."
                }
            ]
        },
        {
            "module_num": "4",
            "module_title": "Module Bilans Biologiques & Imagerie Médicale (Laboratoire)",
            "module_desc": "Ordonnances d'analyses complémentaires, examens prescrits, téléversement de feuilles de résultats et validation clinique praticien.",
            "relations": [
                {
                    "title": "Relation 4.1 : Consultation (1) ──── (0..*) LabRequest",
                    "nature": "Association 1-à-Plusieurs (Prescriptions d'analyses)",
                    "cardinality": "Consultation [1] <─── ordonne ───> [0..*] LabRequest",
                    "fk": "lab_requests.consultation_id (not null)",
                    "sens_1": "Une téléconsultation peut engendrer zéro demande d'analyses ou plusieurs bons d'examens (ex: bilan biologique + radio pulmonaire).",
                    "sens_2": "Chaque prescription de bilan de laboratoire est adossée à une consultation d'origine avec référence unique LAB-[AAMM]-[HÔPITAL]-[4CHARS].",
                    "regle": "Précautions cliniques : La demande consigne obligatoirement le caractère à jeun (fasting_required) et le degré d'urgence (normal, urgent).",
                    "cascade": "ON DELETE RESTRICT : Les demandes d'analyses sont archivées de manière pérenne."
                },
                {
                    "title": "Relation 4.2 : LabRequest (1) ──── (1..*) LabRequestItem",
                    "nature": "Composition Forte (Analyses et bilans spécifiques demandés)",
                    "cardinality": "LabRequest [1] <─── comprend ───> [1..*] LabRequestItem",
                    "fk": "lab_request_items.lab_request_id (not null)",
                    "sens_1": "Une demande de laboratoire regroupe au minimum une analyse médicale prescrite (ex: NFS, Glycémie à jeun, Goutte épaisse, Créatinine).",
                    "sens_2": "Chaque analyse demandée est intimement liée à sa demande de laboratoire parente.",
                    "regle": "Catégorisation : Chaque acte est classé selon son domaine médical (biologie, imagerie, parasitologie, bactériologie).",
                    "cascade": "ON DELETE CASCADE : Les actes prescrits disparaissent avec la demande."
                },
                {
                    "title": "Relation 4.3 : LabRequest (1) ──── (0..*) LabRequestResult",
                    "nature": "Composition Forte (Documents et pièces justificatives téléversées)",
                    "cardinality": "LabRequest [1] <─── justifiée par ───> [0..*] LabRequestResult",
                    "fk": "lab_request_results.lab_request_id (not null)",
                    "sens_1": "Une demande d'examen est initialement en attente (0 résultat), puis reçoit un ou plusieurs documents scannés ou photos transmis par le patient ou le labo.",
                    "sens_2": "Chaque fichier de résultat est rattaché au dossier d'examen correspondant.",
                    "regle": "Stockage Sécurisé & HMAC : Fichiers stockés sur le disque privé local (non public). Accès exclusivement autorisé par URL signée temporaire avec clé HMAC.",
                    "cascade": "ON DELETE CASCADE sur les métadonnées et purge des fichiers physiques."
                },
                {
                    "title": "Relation 4.4 : User / Uploader (1) ──── (0..*) LabRequestResult",
                    "nature": "Association d'Audit (Traçabilité du téléversement)",
                    "cardinality": "User [1] <─── téléverse ───> [0..*] LabRequestResult",
                    "fk": "lab_request_results.uploaded_by (not null)",
                    "sens_1": "Un utilisateur (le patient lui-même ou un personnel de laboratoire) transmet de multiples résultats médicaux au fil de son parcours.",
                    "sens_2": "Chaque document médical téléversé porte l'identifiant exact de l'auteur du dépôt.",
                    "regle": "Notification automatique : Le téléversement d'un nouveau résultat notifie immédiatement le praticien prescripteur pour relecture et synthèse.",
                    "cascade": "ON DELETE RESTRICT sur l'auteur du dépôt."
                }
            ]
        },
        {
            "module_num": "5",
            "module_title": "Module E-Pharmacie, Stocks, Commandes & Logistique",
            "module_desc": "Gestion des stocks en officine, passage de commandes de médicaments, décrémentation atomique et livraison par coursier.",
            "relations": [
                {
                    "title": "Relation 5.1 : Pharmacy (1) ──── (0..*) PharmacyStock",
                    "nature": "Composition Forte (Inventaire de l'officine)",
                    "cardinality": "Pharmacy [1] <─── possède en stock ───> [0..*] PharmacyStock",
                    "fk": "pharmacy_stocks.pharmacy_id (not null)",
                    "sens_1": "Une pharmacie gère zéro médicament (à son inscription) ou des milliers de références en stock avec quantités et prix unitaires.",
                    "sens_2": "Une ligne de stock est propre à une officine précise (chaque pharmacie fixe librement son prix de vente et gère ses réapprovisionnements).",
                    "regle": "Verrou Transactionnel : La mise à jour des stocks lors d'une vente en ligne s'effectue sous verrou SQL exclusif (lockForUpdate) pour éliminer tout risque de survente.",
                    "cascade": "ON DELETE CASCADE : La suppression d'une pharmacie purge ses stocks."
                },
                {
                    "title": "Relation 5.2 : Medication (1) ──── (0..*) PharmacyStock",
                    "nature": "Association de Référence Catalogue",
                    "cardinality": "Medication [1] <─── référencé dans ───> [0..*] PharmacyStock",
                    "fk": "pharmacy_stocks.medication_id (not null)",
                    "sens_1": "Une molécule peut être stockée dans zéro pharmacie (rupture nationale) ou dans la totalité des pharmacies partenaires de Lomé et des régions.",
                    "sens_2": "Chaque entrée de stock cible un médicament déterminé du catalogue.",
                    "regle": "Recherche Géolocalisée : Le moteur eDoctor permet aux patients de géolocaliser instantanément l'officine la plus proche disposant du produit en stock.",
                    "cascade": "ON DELETE RESTRICT sur la molécule."
                },
                {
                    "title": "Relation 5.3 : Pharmacy (1) ──── (0..*) Order",
                    "nature": "Association Commerciale 1-à-Plusieurs",
                    "cardinality": "Pharmacy [1] <─── prépare et délivre ───> [0..*] Order",
                    "fk": "orders.pharmacy_id (not null)",
                    "sens_1": "Une officine reçoit et honore de multiples commandes de médicaments émises par les usagers de l'application mobile.",
                    "sens_2": "Chaque commande de panier est adressée à une pharmacie unique pour des raisons de cohérence d'officine et de retrait.",
                    "regle": "Rétribution Officinale : 100% de la valeur des médicaments vendus est reversée à la pharmacie partenaire, sans commission eDoctor sur le produit de santé.",
                    "cascade": "ON DELETE RESTRICT : Sauvegarde comptable impérative des commandes passées."
                },
                {
                    "title": "Relation 5.4 : Prescription (0..1) ──── (0..*) Order",
                    "nature": "Association Optionnelle de Justification Médicale",
                    "cardinality": "Prescription [0..1] <─── justifie légalement ───> [0..*] Order",
                    "fk": "orders.prescription_id (nullable)",
                    "sens_1": "Une ordonnance peut ne pas être encore commandée en pharmacie (0) ou servir à commander les médicaments prescrits (1).",
                    "sens_2": "Une commande de pharmacie peut être sans ordonnance (médicaments en vente libre, parapharmacie) ou liée à une ordonnance valide.",
                    "regle": "Contrôle Anti-Fraude Pharmacie : Si au moins un médicament du panier est classé requires_prescription = true, le système interdit la commande sans ordonnance valide et vérifie que la quantité commandée n'excède pas la posologie prescrite.",
                    "cascade": "ON DELETE RESTRICT."
                },
                {
                    "title": "Relation 5.5 : Order (1) ──── (1..*) OrderItem",
                    "nature": "Composition Forte (Panier de la commande)",
                    "cardinality": "Order [1] <─── contient ───> [1..*] OrderItem",
                    "fk": "order_items.order_id (not null)",
                    "sens_1": "Une commande contient obligatoirement un ou plusieurs articles pharmaceutiques achetés.",
                    "sens_2": "Chaque article de commande est rattaché à son bon de commande.",
                    "regle": "Scellement des Prix : L'enregistrement d'un OrderItem fige le prix unitaire unitaire (unit_price) et total (total_price) au moment de l'achat, protégeant l'acheteur contre toute fluctuation ultérieure.",
                    "cascade": "ON DELETE CASCADE avec la commande."
                },
                {
                    "title": "Relation 5.6 : Order (1) ──── (0..1) Delivery",
                    "nature": "Association 1-à-1 Optionnelle (Option d'expédition à domicile)",
                    "cardinality": "Order [1] <─── acheminée par ───> [0..1] Delivery",
                    "fk": "deliveries.order_id (unique, not null)",
                    "sens_1": "Une commande donne lieu soit à un retrait direct en officine (gratuit, 0 livraison), soit à une course de livraison à domicile (1 livraison).",
                    "sens_2": "Une mission de livraison correspond strictement à une commande de pharmacie identifiée.",
                    "regle": "Calcul GPS Kilométrique : Les frais de livraison sont calculés de manière automatisée par la formule de Haversine entre les coordonnées GPS de la pharmacie et le domicile du patient.",
                    "cascade": "ON DELETE RESTRICT pour traçabilité logistique."
                }
            ]
        },
        {
            "module_num": "6",
            "module_title": "Module Soins à Domicile, Monétisation & Support Usagers",
            "module_desc": "Interventions infirmières de proximité, transactions financières multi-bénéficiaires et gestion des litiges usagers.",
            "relations": [
                {
                    "title": "Relation 6.1 : Prescription (1) ──── (0..1) NurseVisit",
                    "nature": "Association 1-à-1 Optionnelle (Soins infirmiers recommandés)",
                    "cardinality": "Prescription [1] <─── préconise ───> [0..1] NurseVisit",
                    "fk": "nurse_visits.prescription_id (unique, not null)",
                    "sens_1": "Une ordonnance médicale peut spécifier un acte nécessitant un infirmier (home_care_recommended = true) donnant lieu à une visite de soins.",
                    "sens_2": "Une intervention infirmière à domicile s'appuie obligatoirement sur une prescription médicale préalable (injections, pansements lourds, perfusions).",
                    "regle": "Rapport Médical Chiffré : Le champ report consignant les constantes prises au domicile (tension, glycémie, actes réalisés) est chiffré au repos.",
                    "cascade": "ON DELETE RESTRICT pour conformité aux soins infirmiers."
                },
                {
                    "title": "Relation 6.2 : Hospital (1) ──── (0..*) NurseVisit",
                    "nature": "Association de Coordination Hospitalière",
                    "cardinality": "Hospital [1] <─── coordonne et affecte ───> [0..*] NurseVisit",
                    "fk": "nurse_visits.hospital_id (not null)",
                    "sens_1": "L'hôpital de rattachement du médecin supervise et gère la flotte de soins à domicile de sa zone sanitaire.",
                    "sens_2": "Toute visite de soins infirmiers relève de la coordination d'un établissement hospitalier agréé.",
                    "regle": "Affectation : L'administrateur de l'hôpital assigne la visite à un infirmier de garde disponible au sein de sa structure.",
                    "cascade": "ON DELETE RESTRICT."
                },
                {
                    "title": "Relation 6.3 : Consultation (0..1) / Order (0..1) ──── (0..1) Payment",
                    "nature": "Association Polymorphe / Mutuelle de Règlement Financier",
                    "cardinality": "[Consultation / Order] [0..1] <─── réglé par ───> [0..1] Payment",
                    "fk": "payments.consultation_id / payments.order_id (uniques, nullables)",
                    "sens_1": "Une consultation ou une commande engendre un enregistrement de paiement unique par transaction.",
                    "sens_2": "Un paiement est adossé soit à une consultation vidéo, soit à une commande de médicaments en pharmacie.",
                    "regle": "Découpage Financier (Financial Split) : Chaque transaction enregistre automatiquement la ventilation des fonds : part partenaire (100% praticien/pharmacie), part eDoctor (commission plateforme), et part coursier.",
                    "cascade": "ON DELETE RESTRICT : Impossibilité légale et comptable d'effacer une ligne de paiement certifiée."
                },
                {
                    "title": "Relation 6.4 : User (1) ──── (0..*) Claim",
                    "nature": "Association 1-à-Plusieurs (Signalements et réclamations)",
                    "cardinality": "User [1] <─── dépose ───> [0..*] Claim",
                    "fk": "claims.user_id (not null)",
                    "sens_1": "Un usager (patient, médecin ou pharmacien) peut déposer zéro ou plusieurs réclamations en cas de litige ou d'incident technique.",
                    "sens_2": "Chaque réclamation est nominative et traçable par référence unique REC-2026-XXXXX.",
                    "regle": "Résolution Administrative : Les Super-Admins disposent d'un droit exclusif de traitement, d'arbitrage et de clôture des réclamations avec notification push à l'usager.",
                    "cascade": "ON DELETE RESTRICT."
                }
            ]
        }
    ]

    # --- Écriture des Modules et Relations dans le Document ---
    for mod in modules_data:
        # Titre du Module
        mod_h = doc.add_paragraph()
        mod_h.paragraph_format.space_before = Pt(16)
        mod_h.paragraph_format.space_after = Pt(4)
        mod_h_run = mod_h.add_run(f"MODULE {mod['module_num']} : {mod['module_title'].upper()}")
        mod_h_run.font.name = "Calibri"
        mod_h_run.font.size = Pt(13)
        mod_h_run.font.bold = True
        mod_h_run.font.color.rgb = COLOR_PRIMARY

        # Description du Module
        mod_desc_p = doc.add_paragraph()
        mod_desc_p.paragraph_format.space_before = Pt(0)
        mod_desc_p.paragraph_format.space_after = Pt(10)
        d_run = mod_desc_p.add_run(mod["module_desc"])
        d_run.font.name = "Calibri"
        d_run.font.size = Pt(10)
        d_run.font.italic = True
        d_run.font.color.rgb = COLOR_MUTED

        # Boucle sur les relations du module
        for rel in mod["relations"]:
            # Tableau pour la relation
            rel_table = doc.add_table(rows=7, cols=2)
            rel_table.alignment = WD_TABLE_ALIGNMENT.CENTER
            rel_table.autofit = False

            # Largeurs des colonnes : Col 0 = 2.0 pouces, Col 1 = 4.8 pouces (Total 6.8 pouces)
            col_widths = [Inches(1.8), Inches(5.0)]
            for row in rel_table.rows:
                for idx, width in enumerate(col_widths):
                    row.cells[idx].width = width

            # Ligne 0 : En-tête de la relation (fusionné)
            cell_header = rel_table.rows[0].cells[0]
            cell_header.merge(rel_table.rows[0].cells[1])
            set_cell_background(cell_header, HEX_PRIMARY)
            set_cell_margins(cell_header, top=100, bottom=100, left=140, right=140)
            p_head = cell_header.paragraphs[0]
            p_head.paragraph_format.space_before = Pt(0)
            p_head.paragraph_format.space_after = Pt(0)
            r_head = p_head.add_run(rel["title"])
            r_head.font.name = "Calibri"
            r_head.font.size = Pt(10.5)
            r_head.font.bold = True
            r_head.font.color.rgb = RGBColor(255, 255, 255)

            # Lignes de données
            rows_meta = [
                ("Nature du Lien", rel["nature"]),
                ("Cardinalités UML", rel["cardinality"]),
                ("Clé Étrangère (FK)", rel["fk"]),
                ("Sens Direct (1 -> N)", rel["sens_1"]),
                ("Sens Réciproque (N -> 1)", rel["sens_2"]),
                ("Règle Métier & Intégrité", f"{rel['regle']}\nImpact Cascade : {rel['cascade']}")
            ]

            for r_idx, (label, val) in enumerate(rows_meta, start=1):
                c_lbl = rel_table.rows[r_idx].cells[0]
                c_val = rel_table.rows[r_idx].cells[1]

                # Style cellule label
                set_cell_background(c_lbl, HEX_LIGHT_BG)
                set_cell_margins(c_lbl, top=70, bottom=70, left=100, right=100)
                p_lbl = c_lbl.paragraphs[0]
                p_lbl.paragraph_format.space_before = Pt(0)
                p_lbl.paragraph_format.space_after = Pt(0)
                r_lbl = p_lbl.add_run(label)
                r_lbl.font.name = "Calibri"
                r_lbl.font.size = Pt(9)
                r_lbl.font.bold = True
                r_lbl.font.color.rgb = COLOR_PRIMARY

                # Style cellule valeur
                set_cell_background(c_val, "FFFFFF" if r_idx % 2 == 0 else "FAFCFE")
                set_cell_margins(c_val, top=70, bottom=70, left=120, right=120)
                p_val = c_val.paragraphs[0]
                p_val.paragraph_format.space_before = Pt(0)
                p_val.paragraph_format.space_after = Pt(0)
                r_val = p_val.add_run(val)
                r_val.font.name = "Calibri"
                r_val.font.size = Pt(9.5)
                r_val.font.color.rgb = COLOR_DARK

            doc.add_paragraph().paragraph_format.space_after = Pt(6)

    # --- Section Récapitulative : Tableau Synthétique des Cardinalités ---
    doc.add_page_break()

    syn_h = doc.add_paragraph()
    syn_h.paragraph_format.space_before = Pt(10)
    syn_h.paragraph_format.space_after = Pt(4)
    s_run = syn_h.add_run("TABLEAU SYNTHÉTIQUE DES ASSOCIATIONS & CARDINALITÉS DU MODÈLE")
    s_run.font.name = "Calibri"
    s_run.font.size = Pt(14)
    s_run.font.bold = True
    s_run.font.color.rgb = COLOR_PRIMARY

    syn_desc = doc.add_paragraph()
    syn_desc.paragraph_format.space_after = Pt(10)
    sd_run = syn_desc.add_run("Vue d'ensemble matricielle pour soutenance et implémentation sous Système de Gestion de Base de Données Relationnel (PostgreSQL / Laravel Eloquent).")
    sd_run.font.name = "Calibri"
    sd_run.font.size = Pt(9.5)
    sd_run.font.italic = True
    sd_run.font.color.rgb = COLOR_MUTED

    matrix_data = [
        ("Hospital ↔ User", "1", "0..*", "users.hospital_id", "Rattachement hospitalier des praticiens et infirmiers"),
        ("Pharmacy ↔ User", "1", "1", "pharmacies.owner_id", "Titularité déontologique exclusive du pharmacien"),
        ("User (Patient) ↔ Consultation", "1", "0..*", "consultations.patient_id", "Dossier des téléconsultations du patient"),
        ("User (Médecin) ↔ Consultation", "1", "0..*", "consultations.doctor_id", "Actes médicaux pris en charge par le praticien"),
        ("Consultation ↔ Message", "1", "0..*", "messages.consultation_id", "Fil de discussion chiffré de la consultation"),
        ("Consultation ↔ Prescription", "1", "0..1", "prescriptions.consultation_id", "Ordonnance médicale émise lors de la consultation"),
        ("Prescription ↔ PrescriptionItem", "1", "1..*", "prescription_items.prescription_id", "Lignes de posologie de l'ordonnance"),
        ("Medication ↔ PrescriptionItem", "1", "0..*", "prescription_items.medication_id", "Médicaments prescrits issus du catalogue"),
        ("Consultation ↔ LabRequest", "1", "0..*", "lab_requests.consultation_id", "Demandes d'analyses complémentaires prescrites"),
        ("LabRequest ↔ LabRequestItem", "1", "1..*", "lab_request_items.lab_request_id", "Examens biologiques et radiologiques demandés"),
        ("LabRequest ↔ LabRequestResult", "1", "0..*", "lab_request_results.lab_request_id", "Résultats et comptes-rendus d'analyses téléversés"),
        ("Pharmacy ↔ PharmacyStock", "1", "0..*", "pharmacy_stocks.pharmacy_id", "Inventaire des stocks disponibles en officine"),
        ("Medication ↔ PharmacyStock", "1", "0..*", "pharmacy_stocks.medication_id", "Disponibilité d'un médicament en officine"),
        ("Pharmacy ↔ Order", "1", "0..*", "orders.pharmacy_id", "Commandes reçues et préparées par l'officine"),
        ("Prescription ↔ Order", "0..1", "0..*", "orders.prescription_id", "Justification médicale d'une commande d'ordonnance"),
        ("Order ↔ OrderItem", "1", "1..*", "order_items.order_id", "Lignes d'articles commandés dans le panier"),
        ("Order ↔ Delivery", "1", "0..1", "deliveries.order_id", "Mission de livraison par coursier à domicile"),
        ("Prescription ↔ NurseVisit", "1", "0..1", "nurse_visits.prescription_id", "Prescription d'actes de soins infirmiers"),
        ("Consultation / Order ↔ Payment", "0..1", "0..1", "payments.[consultation|order]_id", "Règlement financier sécurisé (FedaPay)"),
        ("User ↔ Claim", "1", "0..*", "claims.user_id", "Réclamations, assistance et litiges usagers"),
        ("User ↔ Notification", "1", "0..*", "notifications.user_id", "Alertes push et notifications système en temps réel")
    ]

    mat_table = doc.add_table(rows=len(matrix_data) + 1, cols=5)
    mat_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    mat_table.autofit = False

    m_widths = [Inches(1.8), Inches(0.7), Inches(0.7), Inches(1.8), Inches(2.0)]
    for row in mat_table.rows:
        for idx, w in enumerate(m_widths):
            row.cells[idx].width = w

    headers_mat = ["Association / Entités", "Card. A", "Card. B", "Clé Étrangère (FK)", "Signification & Règle Métier"]
    for idx, text in enumerate(headers_mat):
        c = mat_table.rows[0].cells[idx]
        set_cell_background(c, HEX_PRIMARY)
        set_cell_margins(c, top=80, bottom=80, left=80, right=80)
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER if idx in [1, 2] else WD_ALIGN_PARAGRAPH.LEFT
        r = p.add_run(text)
        r.font.name = "Calibri"
        r.font.size = Pt(8.5)
        r.font.bold = True
        r.font.color.rgb = RGBColor(255, 255, 255)

    for r_idx, row_vals in enumerate(matrix_data, start=1):
        for c_idx, val in enumerate(row_vals):
            c = mat_table.rows[r_idx].cells[c_idx]
            bg = "FFFFFF" if r_idx % 2 == 0 else HEX_LIGHT_BG
            set_cell_background(c, bg)
            set_cell_margins(c, top=60, bottom=60, left=80, right=80)
            p = c.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if c_idx in [1, 2] else WD_ALIGN_PARAGRAPH.LEFT
            r = p.add_run(val)
            r.font.name = "Calibri"
            r.font.size = Pt(8.5)
            r.font.bold = (c_idx in [1, 2])
            r.font.color.rgb = COLOR_PRIMARY if c_idx in [1, 2] else COLOR_DARK

    output_path = r"c:\Users\belou\Documents\edoctor\SPECIFICATION_UML_RELATIONS_CARDINALITES_EDOCTOR.docx"
    doc.save(output_path)
    print(f"Document créé avec succès : {output_path}")

if __name__ == "__main__":
    create_document()
