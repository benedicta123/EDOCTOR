import os
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

PRIMARY_GREEN = RGBColor(82, 153, 39)     # #529927 (Vert Santé eDoctor)
DARK_NAVY = RGBColor(19, 42, 69)          # #132A45 (Bleu Institutionnel)
TEXT_MUTED = RGBColor(100, 116, 139)      # #64748B
DARK_GRAY = RGBColor(30, 41, 59)          # #1E293B
GOLD_AMBER = RGBColor(217, 119, 6)        # #D97706

def set_cell_background(cell, color_hex):
    shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{color_hex}"/>')
    cell._tc.get_or_add_tcPr().append(shading)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('top', top), ('bottom', bottom), ('left', left), ('right', right)]:
        node = OxmlElement(f'w:{m}')
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

def create_monetization_docx(output_path):
    doc = Document()

    # Configuration des marges de page
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)

        # En-tête
        hp = section.header.paragraphs[0]
        hp.text = "eDoctor (Togo Health Direct) — Modèle Économique & Tarification Stratégique"
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        if hp.runs:
            hp.runs[0].font.size = Pt(8.5)
            hp.runs[0].font.color.rgb = TEXT_MUTED

        # Pied de page
        fp = section.footer.paragraphs[0]
        fp.text = "Document Stratégique de Direction • Version 2.0 (Octobre 2026) • Directives DG"
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        if fp.runs:
            fp.runs[0].font.size = Pt(8.5)
            fp.runs[0].font.color.rgb = TEXT_MUTED

    # Titre Principal
    p_title = doc.add_paragraph()
    p_title.paragraph_format.space_before = Pt(8)
    p_title.paragraph_format.space_after = Pt(4)
    run_title = p_title.add_run("📊 Modèle Économique & Stratégie de Monétisation eDoctor")
    run_title.font.name = 'Arial'
    run_title.font.size = Pt(19)
    run_title.font.bold = True
    run_title.font.color.rgb = DARK_NAVY

    # Sous-titre
    p_sub = doc.add_paragraph()
    p_sub.paragraph_format.space_after = Pt(12)
    run_sub = p_sub.add_run("Version 2.0 — Directives de la Direction Générale : Liberté Tarifaire Partenaire, Zéro Prélèvement B2B et Frais de Service Fixes")
    run_sub.font.name = 'Arial'
    run_sub.font.size = Pt(10.5)
    run_sub.font.italic = True
    run_sub.font.color.rgb = TEXT_MUTED

    # Encadré Synthèse Stratégique
    p_box = doc.add_paragraph()
    p_box.paragraph_format.space_after = Pt(14)
    r_box = p_box.add_run(
        "💡 Synthèse Décisionnelle DG : Pour maximiser l'adhésion massive des hôpitaux et pharmacies au Togo, "
        "eDoctor applique une politique de ZÉRO PRÉLÈVEMENT sur les honoraires médicaux et sur les ventes de médicaments. "
        "Les hôpitaux fixent librement leurs tarifs et perçoivent 100% de leur prix. Les pharmacies perçoivent 100% du prix des produits. "
        "Le modèle économique d'eDoctor repose sur des frais de service plateforme proportionnels et équitables payés par le patient "
        "(10% du tarif de consultation de l'hôpital incluant les frais Mobile Money, 150 FCFA par ordonnance trouvée en pharmacie de proximité), "
        "complétés par une tarification kilométrique juste de la livraison (500 FCFA pour les 2 premiers km + 150 FCFA/km sup)."
    )
    r_box.font.name = 'Arial'
    r_box.font.size = Pt(9.5)
    r_box.font.bold = True
    r_box.font.color.rgb = PRIMARY_GREEN

    # ─────────────────────────────────────────────────────────────
    # SECTION 1 : LES HÔPITAUX & CLINIQUES (0% PRÉLÈVEMENT)
    # ─────────────────────────────────────────────────────────────
    h1 = doc.add_paragraph()
    h1.paragraph_format.space_before = Pt(12)
    h1.paragraph_format.space_after = Pt(4)
    r_h1 = h1.add_run("1. Hôpitaux & Cliniques Partenaires : Liberté Tarifaire et 100% de Reversement")
    r_h1.font.name = 'Arial'
    r_h1.font.size = Pt(13)
    r_h1.font.bold = True
    r_h1.font.color.rgb = DARK_NAVY

    p1 = doc.add_paragraph()
    p1.add_run(
        "Pour lever tout frein à la contractualisation avec les CHU, hôpitaux préfectoraux et cliniques privées du Togo, "
        "la Direction Générale instaure un principe d'adhésion sans ponction sur l'acte médical :"
    )

    hosp_points = [
        ("Liberté tarifaire totale accordée aux structures de santé : ",
         "Chaque établissement hospitalier ou praticien définit librement son tarif de téléconsultation (ex: 2 500 FCFA pour un centre public, "
         "5 000 FCFA pour un généraliste en clinique, 10 000 FCFA pour un spécialiste en cardiologie ou pédiatrie)."),
        ("Zéro prélèvement sur les honoraires (100% reversé à l'hôpital) : ",
         "eDoctor ne prélève aucun pourcentage sur le montant fixé par la structure. L'intégralité (100%) des honoraires de consultation "
         "est reversée à l'hôpital sans aucune retenue."),
        ("Frais de service plateforme eDoctor (10% du tarif hôpital payés par le patient) : ",
         "Lors du paiement, la plateforme applique des frais proportionnels de 10% calculés directement sur le tarif de consultation fixé par l'établissement. "
         "Ce montant couvre l'infrastructure technologique sécurisée, la visio-consultation chiffrée, l'archivage du dossier médical et intègre/absorbe l'intégralité des frais "
         "de passerelle financière Mobile Money (T-Money, Flooz)."),
        ("Exemple concret de facturation : ",
         "Si le CHU fixe la consultation à 3 000 FCFA, les frais eDoctor sont de 10% soit 300 FCFA. Le patient règle au total 3 300 FCFA via son compte T-Money. L'hôpital perçoit exactement "
         "3 000 FCFA (100%), et eDoctor perçoit 300 FCFA de frais de service net. Pour une consultation à 5 000 FCFA, eDoctor perçoit 500 FCFA (10%) et le patient règle 5 500 FCFA."),
        ("Bénéfices indirects majeurs pour l'hôpital : ",
         "Optimisation des temps soignants en heures creuses, zéro impayé grâce au prépaiement sécurisé, et orientation des patients vers "
         "le plateau technique physique de l'hôpital pour les examens complémentaires prescrits (radiologie, analyses de sang).")
    ]
    for bold_text, normal_text in hosp_points:
        p = doc.add_paragraph(style='List Bullet')
        r1 = p.add_run(bold_text)
        r1.font.bold = True
        r1.font.color.rgb = DARK_GRAY
        r2 = p.add_run(normal_text)
        r2.font.color.rgb = DARK_GRAY

    # ─────────────────────────────────────────────────────────────
    # SECTION 2 : LES PHARMACIES D'OFFICINE
    # ─────────────────────────────────────────────────────────────
    h2 = doc.add_paragraph()
    h2.paragraph_format.space_before = Pt(12)
    h2.paragraph_format.space_after = Pt(4)
    r_h2 = h2.add_run("2. Pharmacies d'Officine : 100% du Prix des Médicaments & Zéro Commission")
    r_h2.font.name = 'Arial'
    r_h2.font.size = Pt(13)
    r_h2.font.bold = True
    r_h2.font.color.rgb = DARK_NAVY

    p2 = doc.add_paragraph()
    p2.add_run(
        "Le secteur pharmaceutique togolais étant soumis à une réglementation stricte des prix des spécialités, "
        "eDoctor protège intégralement la marge de l'officine partenaire :"
    )

    pharm_points = [
        ("Zéro prélèvement sur la vente des médicaments : ",
         "La pharmacie perçoit 100% de la valeur faciale officielle des médicaments délivrés. eDoctor ne prend aucune commission sur le panier de santé."),
        ("Frais de mise en relation & géolocalisation de stock (150 FCFA) : ",
         "Pour chaque commande passée sur la plateforme, un forfait de 150 FCFA est ajouté au panier du patient. Ce montant rémunère "
         "le service eDoctor d'identification en direct de l'officine de garde la plus proche disposant de l'intégralité des molécules en stock."),
        ("Paiement garanti et zéro perte sur impayé : ",
         "La commande est obligatoirement solvabilisée et prépayée par le patient avant préparation. Le pharmacien prépare sereinement la commande "
         "sans risque de désistement."),
        ("Écoulement des stocks et élargissement de la zone de chalandise : ",
         "L'officine touche des patients bien au-delà de son quartier habituel grâce au réseau de coursiers eDoctor.")
    ]
    for bold_text, normal_text in pharm_points:
        p = doc.add_paragraph(style='List Bullet')
        r1 = p.add_run(bold_text)
        r1.font.bold = True
        r1.font.color.rgb = DARK_GRAY
        r2 = p.add_run(normal_text)
        r2.font.color.rgb = DARK_GRAY

    # ─────────────────────────────────────────────────────────────
    # SECTION 3 : SERVICE DE LIVRAISON EXPRESS KILOMÉTRIQUE
    # ─────────────────────────────────────────────────────────────
    h3 = doc.add_paragraph()
    h3.paragraph_format.space_before = Pt(12)
    h3.paragraph_format.space_after = Pt(4)
    r_h3 = h3.add_run("3. Logistique & Livraison de Médicaments : Grille Kilométrique Équitable")
    r_h3.font.name = 'Arial'
    r_h3.font.size = Pt(13)
    r_h3.font.bold = True
    r_h3.font.color.rgb = DARK_NAVY

    p3 = doc.add_paragraph()
    p3.add_run(
        "Pour assurer une rémunération équitable des coursiers partenaires tout en maintenant un tarif accessible pour les patients, "
        "la tarification de livraison s'établit sur un barème kilométrique dynamique :"
    )

    livr_points = [
        ("Forfait de base déclencheur : ", "500 FCFA incluant les 2 premiers kilomètres."),
        ("Tarif kilométrique additionnel : ", "150 FCFA par kilomètre supplémentaire au-delà des 2 premiers kilomètres."),
        ("Formule mathématique de calcul : ", "Frais de livraison = 500 FCFA + [max(0, Distance_km - 2) × 150 FCFA]."),
        ("Exemple A (Proximité immédiate ≤ 2 km) : ", "Frais de livraison = 500 FCFA."),
        ("Exemple B (Moyenne distance = 5 km) : ", "500 FCFA + (3 km × 150 FCFA) = 500 + 450 = 950 FCFA."),
        ("Exemple C (Longue distance = 8 km) : ", "500 FCFA + (6 km × 150 FCFA) = 500 + 900 = 1 400 FCFA."),
        ("Modèle de partage avec le coursier : ",
         "Le coursier agréé reçoit ~75% du tarif de livraison (rémunération de son carburant et de sa prestation), "
         "tandis qu'eDoctor conserve ~25% de marge de coordination logistique et d'assurance pli scellé.")
    ]
    for bold_text, normal_text in livr_points:
        p = doc.add_paragraph(style='List Bullet')
        r1 = p.add_run(bold_text)
        r1.font.bold = True
        r1.font.color.rgb = DARK_GRAY
        r2 = p.add_run(normal_text)
        r2.font.color.rgb = DARK_GRAY

    # ─────────────────────────────────────────────────────────────
    # SECTION 4 : TABLEAU RÉCAPITULATIF DES FLUX FINANCIERS
    # ─────────────────────────────────────────────────────────────
    h4 = doc.add_paragraph()
    h4.paragraph_format.space_before = Pt(14)
    h4.paragraph_format.space_after = Pt(6)
    r_h4 = h4.add_run("4. Matrice de Répartition Financière par Transaction (en FCFA)")
    r_h4.font.name = 'Arial'
    r_h4.font.size = Pt(13)
    r_h4.font.bold = True
    r_h4.font.color.rgb = DARK_NAVY

    table = doc.add_table(rows=1, cols=5)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False

    headers = [
        "Nature de l'Opération",
        "Total Réglé par Patient",
        "Part Reversée Hôpital",
        "Part Pharmacie / Coursier",
        "Revenu Net eDoctor"
    ]
    hdr_cells = table.rows[0].cells
    for i, title in enumerate(headers):
        hdr_cells[i].text = title
        set_cell_background(hdr_cells[i], "132A45")
        set_cell_margins(hdr_cells[i], top=120, bottom=120, left=80, right=80)
        p = hdr_cells[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for run in p.runs:
            run.font.name = 'Arial'
            run.font.size = Pt(9)
            run.font.bold = True
            run.font.color.rgb = RGBColor(255, 255, 255)

    data_rows = [
        ("Téléconsultation Dispensaire (2 000 F)", "2 200 FCFA", "2 000 FCFA (100%)", "—", "200 FCFA (10% tarif hôpital)"),
        ("Téléconsultation Standard CHU (3 000 F)", "3 300 FCFA", "3 000 FCFA (100%)", "—", "300 FCFA (10% tarif hôpital)"),
        ("Téléconsultation Généraliste (3 500 F)", "3 850 FCFA", "3 500 FCFA (100%)", "—", "350 FCFA (10% tarif hôpital)"),
        ("Téléconsultation Spécialiste (7 000 F)", "7 700 FCFA", "7 000 FCFA (100%)", "—", "700 FCFA (10% tarif hôpital)"),
        ("Commande Pharmacie (Retrait comptoir)", "Prix Médicaments + 150 F", "—", "100% Prix Médicaments", "150 FCFA (Frais mise en rel.)"),
        ("Commande Pharmacie + Livraison (4 km)", "Prix Médoc + 150 F + 800 F", "—", "100% Médoc + 600 F Coursier", "350 FCFA (150F + 200F Marge livr.)"),
        ("Soins Infirmiers à Domicile (5 000 F)", "5 500 FCFA", "5 000 FCFA (100% Hôpital)", "—", "500 FCFA (10% tarif soin)")
    ]

    for row_idx, row_data in enumerate(data_rows):
        row = table.add_row()
        bg_color = "F8FAFC" if row_idx % 2 == 0 else "FFFFFF"
        for col_idx, cell_value in enumerate(row_data):
            cell = row.cells[col_idx]
            cell.text = cell_value
            set_cell_background(cell, bg_color)
            set_cell_margins(cell, top=90, bottom=90, left=80, right=80)
            p = cell.paragraphs[0]
            if col_idx in [1, 2, 3, 4]:
                p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
            if col_idx == 4:
                for r in p.runs:
                    r.font.bold = True
                    r.font.color.rgb = PRIMARY_GREEN
            elif col_idx == 0:
                for r in p.runs:
                    r.font.bold = True
                    r.font.color.rgb = DARK_NAVY
            for r in p.runs:
                r.font.name = 'Arial'
                r.font.size = Pt(8.5)

    # ─────────────────────────────────────────────────────────────
    # SECTION 5 : PROJECTION DE REVENUS MENSUELS
    # ─────────────────────────────────────────────────────────────
    h5 = doc.add_paragraph()
    h5.paragraph_format.space_before = Pt(14)
    h5.paragraph_format.space_after = Pt(4)
    r_h5 = h5.add_run("5. Projection Financière Mensuelle basée sur le Volume (Phase 1 de Lancement)")
    r_h5.font.name = 'Arial'
    r_h5.font.size = Pt(13)
    r_h5.font.bold = True
    r_h5.font.color.rgb = DARK_NAVY

    projections = [
        ("Téléconsultations (2 000 actes/mois avec panier moyen 3 500 F et 10% eDoctor soit 350 FCFA) : ", "Revenu eDoctor = 700 000 FCFA / mois."),
        ("Commandes Pharmacies (3 000 ordonnances/mois à 150 FCFA) : ", "Revenu eDoctor = 450 000 FCFA / mois."),
        ("Livraisons Express (1 500 courses/mois avec marge moyenne de 250 FCFA) : ", "Revenu eDoctor = 375 000 FCFA / mois."),
        ("Soins Infirmiers à Domicile (400 actes/mois à 10% soit 500 FCFA de frais eDoctor) : ", "Revenu eDoctor = 200 000 FCFA / mois."),
        ("👉 TOTAL REVENU MENSUEL RÉCURRENT BRUT eDOCTOR : ", "≈ 1 725 000 FCFA / mois (soit plus de 20,7 Millions FCFA / an dès le cap des 3 000 usagers réguliers).")
    ]
    for bold_text, normal_text in projections:
        p = doc.add_paragraph(style='List Bullet')
        r1 = p.add_run(bold_text)
        r1.font.bold = True
        r1.font.color.rgb = DARK_NAVY if "TOTAL" not in bold_text else PRIMARY_GREEN
        r2 = p.add_run(normal_text)
        r2.font.bold = "TOTAL" in bold_text
        r2.font.color.rgb = DARK_GRAY if "TOTAL" not in bold_text else PRIMARY_GREEN

    # ─────────────────────────────────────────────────────────────
    # SECTION 6 : GESTION DES FLUX MOBILE MONEY & SÉCURISATION
    # ─────────────────────────────────────────────────────────────
    h6 = doc.add_paragraph()
    h6.paragraph_format.space_before = Pt(14)
    h6.paragraph_format.space_after = Pt(4)
    r_h6 = h6.add_run("6. Mécanisme de Split Automatique & Déblocage des Fonds")
    r_h6.font.name = 'Arial'
    r_h6.font.size = Pt(13)
    r_h6.font.bold = True
    r_h6.font.color.rgb = DARK_NAVY

    p6 = doc.add_paragraph()
    p6.add_run(
        "L'encaissement et le reversement fonctionnent de manière entièrement automatisée grâce à l'intégration des API Mobile Money togolaises (T-Money Togo Télécom et Flooz Moov Africa) :\n"
        "1. Encaissement Unique : Le patient règle le montant global de l'acte en un seul clic sur son téléphone portable.\n"
        "2. Séquestre Garanti (Escrow) : Les fonds sont immobilisés sur le compte régulé de la plateforme jusqu'à la fin effective de la consultation ou la remise des médicaments.\n"
        "3. Découpage Automatique (Split) : Dès validation médicale, l'API crédite instantanément 100% de la part hôpital dans son solde virtuel partenaire, et alloue la commission de 10% ou 150 FCFA dans le compte eDoctor.\n"
        "4. Reversement Autonome (Payout) : Les hôpitaux et officines peuvent demander un virement bancaire ou un transfert Mobile Money Marchand selon la périodicité souhaitée (quotidienne, hebdomadaire ou mensuelle)."
    )

    doc.save(output_path)
    print(f"Document créé avec succès : {output_path}")

if __name__ == '__main__':
    target = os.path.join(os.getcwd(), 'MODELE_ECONOMIQUE_ET_MONETISATION_EDOCTOR.docx')
    create_monetization_docx(target)
