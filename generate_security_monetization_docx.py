import os
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

PRIMARY_GREEN = RGBColor(82, 153, 39)     # #529927 (Couleur Santé eDoctor)
DARK_NAVY = RGBColor(19, 42, 69)          # #132A45
TEXT_MUTED = RGBColor(100, 116, 139)      # #64748B
DARK_GRAY = RGBColor(30, 41, 59)          # #1E293B
CRIMSON_RED = RGBColor(220, 38, 38)       # #DC2626
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

def create_full_financial_security_docx(output_path):
    doc = Document()

    # Configuration des marges
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)

        # En-tête
        hp = section.header.paragraphs[0]
        hp.text = "eDoctor (Togo Health Direct) — Modèle Financier, Sécurité & Anti-Contournement"
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        if hp.runs:
            hp.runs[0].font.size = Pt(8.5)
            hp.runs[0].font.color.rgb = TEXT_MUTED

        # Pied de page
        fp = section.footer.paragraphs[0]
        fp.text = "Document Stratégique & Opérationnel • eDoctor 2026 • Confidentialité Médicale & Régulation"
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        if fp.runs:
            fp.runs[0].font.size = Pt(8.5)
            fp.runs[0].font.color.rgb = TEXT_MUTED

    # Titre Principal
    p_title = doc.add_paragraph()
    p_title.paragraph_format.space_before = Pt(10)
    p_title.paragraph_format.space_after = Pt(4)
    run_title = p_title.add_run("🛡️ eDoctor — Modèle Financier, Sécurité & Lutte Anti-Contournement")
    run_title.font.name = 'Arial'
    run_title.font.size = Pt(19)
    run_title.font.bold = True
    run_title.font.color.rgb = DARK_NAVY

    # Sous-titre
    p_sub = doc.add_paragraph()
    p_sub.paragraph_format.space_after = Pt(14)
    run_sub = p_sub.add_run("Réponses opérationnelles : Paiement préalable, mécanisme d'Escrow, monétisation sans friction et verrous anti-fraude")
    run_sub.font.name = 'Arial'
    run_sub.font.size = Pt(11)
    run_sub.font.italic = True
    run_sub.font.color.rgb = TEXT_MUTED

    # Note d'introduction
    p_box = doc.add_paragraph()
    p_box.paragraph_format.space_after = Pt(16)
    r_box = p_box.add_run(
        "Ce document apporte les réponses précises et opérationnelles aux problématiques de trésorerie, d'adhésion des hôpitaux, "
        "de synchronisation des paiements Mobile Money et de protection contre les tentatives de désintermédiation (paiement cash ou WhatsApp)."
    )
    r_box.font.name = 'Arial'
    r_box.font.size = Pt(10)
    r_box.font.bold = True
    r_box.font.color.rgb = PRIMARY_GREEN

    # ─────────────────────────────────────────────────────────────
    # QUESTION 1 : ABONNEMENT vs COMMISSION
    # ─────────────────────────────────────────────────────────────
    h1 = doc.add_paragraph()
    h1.paragraph_format.space_before = Pt(14)
    h1.paragraph_format.space_after = Pt(6)
    r_h1 = h1.add_run("1. L'Hôpital doit-il payer un abonnement avant de commencer ? (NON)")
    r_h1.font.name = 'Arial'
    r_h1.font.size = Pt(13)
    r_h1.font.bold = True
    r_h1.font.color.rgb = DARK_NAVY

    p1 = doc.add_paragraph()
    p1.add_run(
        "L'adhésion d'un hôpital ou d'une clinique est à 0 FCFA d'investissement initial (Zéro friction à l'adoption).\n"
        "• Modèle purement au succès (Success-Fee) : L'établissement ne débourse aucun centime pour s'inscrire, homologuer ses médecins "
        "et ouvrir son service. eDoctor ne prélève sa commission (15% à 20%) que lorsque l'hôpital gagne effectivement de l'argent sur une consultation réalisée.\n"
        "• L'abonnement « eDoctor Pro » est une option B2B future : Il ne s'adresse qu'aux grandes polycliniques privées qui souhaiteront "
        "plus tard des fonctionnalités avancées de gestion interne (logiciel de gestion de paie des gardes, intégration avec leur propre ERP hospitalier, sous-domaine web dédié). "
        "Au lancement, 100% des hôpitaux fonctionnent sur le modèle gratuit à l'inscription avec commission à l'acte."
    )

    # ─────────────────────────────────────────────────────────────
    # QUESTION 2 : TIMING DU PAIEMENT & SÉQUESTRE (ESCROW)
    # ─────────────────────────────────────────────────────────────
    h2 = doc.add_paragraph()
    h2.paragraph_format.space_before = Pt(14)
    h2.paragraph_format.space_after = Pt(6)
    r_h2 = h2.add_run("2. Le Patient paie-t-il AVANT la consultation ? (OUI, principe de l'Escrow)")
    r_h2.font.name = 'Arial'
    r_h2.font.size = Pt(13)
    r_h2.font.bold = True
    r_h2.font.color.rgb = DARK_NAVY

    p2 = doc.add_paragraph()
    p2.add_run(
        "Il ne faut pas confondre le moment où le patient est débité et le moment où le médecin perçoit les fonds :\n\n"
        "Étape A — Paiement préalable obligatoire (T-0) :\n"
        "Le patient valide son paiement par T-Money ou Flooz AVANT que la mise en relation n'ait lieu. "
        "Le médecin ne décroche JAMAIS pour une consultation non payée. Cela protège le praticien contre les patients indélicats qui raccrocheraient sans payer.\n\n"
        "Étape B — Séquestre temporaire (Compte Tampon) :\n"
        "L'argent débité n'est pas encore versé dans la poche du médecin. Il est sécurisé sur le compte séquestre eDoctor. "
        "Pourquoi ? Si le médecin ne répond pas, ou si la connexion internet coupe avant le démarrage, le patient est remboursé automatiquement à 100% sans litige.\n\n"
        "Étape C — Le Déclencheur d'acte (/end) :\n"
        "Dès que le médecin clique sur « Clôturer la consultation » et valide son diagnostic, le système considère l'acte médical comme légalement accompli. "
        "L'API exécute alors le Split instantané : 85% vont au portefeuille du praticien, et 15% restent à eDoctor."
    )

    # ─────────────────────────────────────────────────────────────
    # QUESTION 3 : SOINS INFIRMIERS ET RISQUE DE CASH À DOMICILE
    # ─────────────────────────────────────────────────────────────
    h3 = doc.add_paragraph()
    h3.paragraph_format.space_before = Pt(14)
    h3.paragraph_format.space_after = Pt(6)
    r_h3 = h3.add_run("3. Comment empêcher l'Infirmier de prendre l'argent en liquide à domicile ?")
    r_h3.font.name = 'Arial'
    r_h3.font.size = Pt(13)
    r_h3.font.bold = True
    r_h3.font.color.rgb = DARK_NAVY

    p3 = doc.add_paragraph()
    p3.add_run(
        "Le risque de perception de cash à domicile est neutralisé par 4 barrières techniques et organisationnelles infranchissables :\n\n"
        "1. La Mission est obligatoirement prépayée sur l'application :\n"
        "Pour qu'un infirmier reçoive sur son écran la notification de mission avec l'adresse du patient et le détail du soin, "
        "le patient a DÉJÀ réglé l'intégralité du soin (ex: 8 000 FCFA) sur eDoctor. L'infirmier n'a aucune raison de demander du cash, "
        "et le patient refusera catégoriquement de payer une seconde fois en espèces !\n\n"
        "2. Système de Code de Déclenchement OTP Sécurisé :\n"
        "Lorsque le soin est commandé, un code OTP à 4 chiffres est généré sur le téléphone du patient. À son arrivée, l'infirmier doit "
        "demander ce code au patient et le saisir dans son application eDoctor pour valider le début et la fin de l'intervention. "
        "C'est cette saisie qui débloque la rémunération de l'infirmier.\n\n"
        "3. L'infirmier est rattaché à son Hôpital (Responsabilité Hiérarchique) :\n"
        "Sur eDoctor, les infirmiers ne sont pas des travailleurs indépendants anonymes : ils sont obligatoirement rattachés à un Hôpital partenaire vérifié. "
        "Si un infirmier tente de négocier du cash hors plateforme, le patient peut le signaler en 1 clic dans l'onglet « Assistance & Réclamations ». "
        "L'infirmier risque un conseil de discipline, la suspension de son agrément et le renvoi par sa direction hospitalière.\n\n"
        "4. Fiche de transmission & Matériel médical tracé :\n"
        "Pour les pansements spécifiques ou perfusions, les consommables sont préparés par la pharmacie hospitalière sur la base du bon de commande eDoctor. "
        "Un acte sauvage hors plateforme ne dispose d'aucun matériel tracé ni de couverture en responsabilité civile en cas d'accident de soin."
    )

    # ─────────────────────────────────────────────────────────────
    # QUESTION 4 : ANTI-CONTOURNEMENT POUR LES MÉDECINS
    # ─────────────────────────────────────────────────────────────
    h4 = doc.add_paragraph()
    h4.paragraph_format.space_before = Pt(14)
    h4.paragraph_format.space_after = Pt(6)
    r_h4 = h4.add_run("4. Comment empêcher les Médecins de contourner le système (WhatsApp / T-Money direct) ?")
    r_h4.font.name = 'Arial'
    r_h4.font.size = Pt(13)
    r_h4.font.bold = True
    r_h4.font.color.rgb = DARK_NAVY

    p4 = doc.add_paragraph()
    p4.add_run(
        "La désintermédiation est la hantise des plateformes. Voici les 5 piliers qui rendent le contournement inintéressant et dangereux pour le médecin :\n\n"
        "Pilier 1 : L'Ordonnance Électronique Sécurisée & QR Code Infalsifiable :\n"
        "Un médecin sur WhatsApp peut écrire un message texte, mais ce message N'EST PAS une ordonnance légale. Les pharmacies partenaires eDoctor "
        "et les officines togolaises n'acceptent que l'ordonnance officielle eDoctor générée avec le numéro d'enregistrement MSHP du praticien, "
        "le code de référence de la consultation (CNS-2609-CHUD-XXXX) et le QR Code de vérification. Sans consultation eDoctor, pas d'ordonnance valide pour le patient !\n\n"
        "Pilier 2 : Le Dossier Médical & la Prise en charge Assurance (INAM, Gras Savoye, Sunu) :\n"
        "Pour que le patient soit remboursé par sa mutuelle ou l'assurance maladie universelle, l'acte doit figurer dans le Dossier Médical Partagé "
        "avec une feuille de soins numérique officielle. Un échange informel sur WhatsApp est rejeté à 100% par les assureurs. Le patient exige donc de rester sur eDoctor.\n\n"
        "Pilier 3 : Anonymisation des coordonnées téléphoniques (Masquage Numérique) :\n"
        "Lors d'une téléconsultation eDoctor, le patient et le médecin ne voient JAMAIS le numéro de téléphone personnel de l'autre. "
        "La visioconsultation et le chat s'exécutent entièrement dans l'application via des canaux WebRTC chiffrés. Le patient ne peut donc pas enregistrer le numéro du médecin pour le rappeler en direct.\n\n"
        "Pilier 4 : La Garantie Absolue de Paiement pour le Praticien :\n"
        "Les médecins savent d'expérience que lorsqu'ils donnent des conseils par WhatsApp ou appel téléphonique classique, 8 fois sur 10 le patient promet "
        "d'envoyer de l'argent par T-Money et ne l'envoie jamais. Sur eDoctor, le médecin a la garantie contractuelle et automatique que l'argent est déjà prélevé "
        "et disponible. La plateforme lui évite d'avoir à réclamer son honoraire, ce que les médecins détestent déontologiquement faire.\n\n"
        "Pilier 5 : Conventionnement Hospitalier & Détection Algorithmique :\n"
        "Les comptes médecins sont créés sous la tutelle de leur hôpital. Si un praticien a un taux anormalement élevé de consultations écourtées ou de patients "
        "qui annulent pour passer en direct, un audit interne est déclenché avec risque de radiation de la plateforme."
    )

    # ─────────────────────────────────────────────────────────────
    # QUESTION 5 : SÉCURISATION DU WEBHOOK FEDAPAY & PAIEMENTS EN PRODUCTION
    # ─────────────────────────────────────────────────────────────
    h_prod = doc.add_paragraph()
    h_prod.paragraph_format.space_before = Pt(14)
    h_prod.paragraph_format.space_after = Pt(6)
    r_h_prod = h_prod.add_run("5. Comment sécuriser techniquement les passerelles de paiement en Production ?")
    r_h_prod.font.name = 'Arial'
    r_h_prod.font.size = Pt(13)
    r_h_prod.font.bold = True
    r_h_prod.font.color.rgb = DARK_NAVY

    p_prod = doc.add_paragraph()
    p_prod.add_run(
        "Pour éliminer tout risque d'attaque informatique, de simulation frauduleuse ou de rejeu sur les transactions financières, "
        "eDoctor a déployé 4 verrous cryptographiques inaltérables en production :\n\n"
        "1. Verrouillage absolu des paiements simulés en Production :\n"
        "Toute requête tentant de simuler directement un paiement (/api/consultations/pay avec paiement direct) est systématiquement "
        "rejetée avec une erreur 403 Forbidden dès que l'environnement passe en mode production (APP_ENV=production). Seuls les flux réels "
        "initiés via FedaPay (Mobile Money T-Money, Flooz, Carte bancaire) sont acceptés.\n\n"
        "2. Signature Cryptographique HMAC du Webhook FedaPay :\n"
        "Chaque notification de confirmation émise par les serveurs FedaPay vers notre API est signée numériquement avec une clé secrète "
        "(FEDAPAY_WEBHOOK_SECRET). Notre contrôleur vérifie l'authenticité de la signature HMAC avant d'accréditer le moindre compte ou "
        "de débloquer une consultation. Les fausses requêtes forgées sont immédiatement neutralisées.\n\n"
        "3. Limitation de Débit Stricte (Rate Limiting 60 req/min) :\n"
        "La route de réception des webhooks (/api/fedapay/webhook) est protégée par un filtre de débit strict limitant le trafic à 60 requêtes "
        "par minute pour interdire les attaques par déni de service (DDoS) ou le bombardement de requêtes falsifiées.\n\n"
        "4. Double Authentification (2FA) sur les comptes à solde financier :\n"
        "Les praticiens, pharmacies et administrateurs gérant des soldes financiers ou des transferts sont protégés par une authentification "
        "forte à deux facteurs (code OTP à 6 chiffres transmis par Brevo) et un blocage automatique après 10 tentatives erronées."
    )

    # ─────────────────────────────────────────────────────────────
    # SYNTHÈSE RÉCAPITULATIVE
    # ─────────────────────────────────────────────────────────────
    h5 = doc.add_paragraph()
    h5.paragraph_format.space_before = Pt(16)
    h5.paragraph_format.space_after = Pt(8)
    r_h5 = h5.add_run("6. Tableau Récapitulatif des Protections & Garanties Financières")
    r_h5.font.name = 'Arial'
    r_h5.font.size = Pt(13)
    r_h5.font.bold = True
    r_h5.font.color.rgb = DARK_NAVY

    table = doc.add_table(rows=1, cols=3)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False

    headers = ["Risque Identifié", "Solution & Verrou Technique eDoctor", "Bénéfice Garanti"]
    hdr_cells = table.rows[0].cells
    for i, title in enumerate(headers):
        hdr_cells[i].text = title
        set_cell_background(hdr_cells[i], "132A45")
        set_cell_margins(hdr_cells[i], top=120, bottom=120, left=100, right=100)
        p = hdr_cells[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for run in p.runs:
            run.font.name = 'Arial'
            run.font.size = Pt(9.5)
            run.font.bold = True
            run.font.color.rgb = RGBColor(255, 255, 255)

    rows_data = [
        ("Hôpital réticent à payer un abonnement", "Inscription gratuite (0 FCFA), modèle 100% au succès basé sur commission à l'acte", "Adoption massive et immédiate des structures"),
        ("Patient qui ne paie pas après l'appel", "Paiement Mobile Money obligatoire AVANT le démarrage (système Escrow)", "100% de consultations payées pour le médecin"),
        ("Simulation frauduleuse de paiement en prod", "Verrouillage strict des paiements directs simulés en production + contrôle FedaPay out-of-band", "Zéro fraude financière possible"),
        ("Rejeu ou falsification de notification Webhook", "Signature cryptographique HMAC (FEDAPAY_WEBHOOK_SECRET) + Rate Limiting 60 req/min", "Intégrité inviolable des encaissements"),
        ("Infirmier qui demande du cash à domicile", "Pré-paiement total sur l'app + Code OTP patient obligatoire pour valider la visite", "Zéro manipulation d'espèces chez le patient"),
        ("Médecin qui dévie le patient sur WhatsApp", "Ordonnance officielle QR Code impossible à émettre hors app + anonymisation du numéro", "Le patient et le médecin ont intérêt absolu à rester sur l'app"),
        ("Usurpation de compte ou piratage de solde", "Double Authentification 2FA obligatoire par email (Brevo) + Verrouillage après 10 échecs", "Sécurité bancaire de niveau institutionnel"),
        ("Litiges ou coupure technique durant l'appel", "Remboursement automatique si l'acte n'est pas clôturé avec diagnostic", "Protection et confiance totale du patient")
    ]

    for row_idx, row_data in enumerate(rows_data):
        row = table.add_row()
        bg_color = "F8FAFC" if row_idx % 2 == 0 else "FFFFFF"
        for col_idx, cell_value in enumerate(row_data):
            cell = row.cells[col_idx]
            cell.text = cell_value
            set_cell_background(cell, bg_color)
            set_cell_margins(cell, top=100, bottom=100, left=100, right=100)
            p = cell.paragraphs[0]
            if col_idx == 0:
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                for r in p.runs:
                    r.font.bold = True
                    r.font.color.rgb = CRIMSON_RED
            elif col_idx == 1:
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                for r in p.runs:
                    r.font.color.rgb = DARK_GRAY
            elif col_idx == 2:
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                for r in p.runs:
                    r.font.bold = True
                    r.font.color.rgb = PRIMARY_GREEN
            for r in p.runs:
                r.font.name = 'Arial'
                r.font.size = Pt(9)

    doc.save(output_path)
    print(f"Document généré avec succès : {output_path}")

if __name__ == '__main__':
    target = os.path.join(os.getcwd(), 'GUIDE_SECURISATION_FINANCIERE_ANTI_CONTOURNEMENT.docx')
    create_full_financial_security_docx(target)
