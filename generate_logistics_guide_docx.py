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

def create_logistics_guide_docx(output_path):
    doc = Document()

    # Configuration des marges
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)

        # En-tête
        hp = section.header.paragraphs[0]
        hp.text = "eDoctor (Togo Health Direct) — Stratégie Logistique & Livraison Pharmaceutique"
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        if hp.runs:
            hp.runs[0].font.size = Pt(8.5)
            hp.runs[0].font.color.rgb = TEXT_MUTED

        # Pied de page
        fp = section.footer.paragraphs[0]
        fp.text = "Document Opérationnel Interne • eDoctor 2026 • Transport de Produits de Santé"
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        if fp.runs:
            fp.runs[0].font.size = Pt(8.5)
            fp.runs[0].font.color.rgb = TEXT_MUTED

    # Titre Principal
    p_title = doc.add_paragraph()
    p_title.paragraph_format.space_before = Pt(10)
    p_title.paragraph_format.space_after = Pt(4)
    run_title = p_title.add_run("🚚 eDoctor — Organisation de la Livraison de Médicaments")
    run_title.font.name = 'Arial'
    run_title.font.size = Pt(19)
    run_title.font.bold = True
    run_title.font.color.rgb = DARK_NAVY

    # Sous-titre
    p_sub = doc.add_paragraph()
    p_sub.paragraph_format.space_after = Pt(14)
    run_sub = p_sub.add_run("Tarification algorithmique transparente, recrutement des coursiers et partage des responsabilités")
    run_sub.font.name = 'Arial'
    run_sub.font.size = Pt(11)
    run_sub.font.italic = True
    run_sub.font.color.rgb = TEXT_MUTED

    # Note d'introduction
    p_box = doc.add_paragraph()
    p_box.paragraph_format.space_after = Pt(16)
    r_box = p_box.add_run(
        "Ce guide répond aux questions opérationnelles critiques : qui fixe le prix de la course, comment informer le patient à l'avance "
        "sans mauvaise surprise, comment recruter les livreurs à Lomé et comment articuler le rôle de la pharmacie."
    )
    r_box.font.name = 'Arial'
    r_box.font.size = Pt(10)
    r_box.font.bold = True
    r_box.font.color.rgb = PRIMARY_GREEN

    # ─────────────────────────────────────────────────────────────
    # QUESTION 1 : QUI FIXE LES FRAIS ET COMMENT INFORMER LE PATIENT ?
    # ─────────────────────────────────────────────────────────────
    h1 = doc.add_paragraph()
    h1.paragraph_format.space_before = Pt(14)
    h1.paragraph_format.space_after = Pt(6)
    r_h1 = h1.add_run("1. Qui fixe les frais de livraison ? (JAMAIS le livreur !)")
    r_h1.font.name = 'Arial'
    r_h1.font.size = Pt(13)
    r_h1.font.bold = True
    r_h1.font.color.rgb = DARK_NAVY

    p1 = doc.add_paragraph()
    p1.add_run(
        "Si le livreur fixait lui-même ses tarifs à la volée, le système s'effondrerait immédiatement : marchandage informel, "
        "surfacturation, méfiance et litiges avec les patients.\n\n"
        "C'est la plateforme eDoctor qui calcule et fixe le tarif de manière 100% automatisée, transparente et définitive :\n"
        "• Calcul automatique par zones et distance kilométrique (GPS) : Dès que le patient sélectionne sa pharmacie et saisit son adresse "
        "ou géolocalise son domicile sur l'application mobile, le système calcule instantanément la distance réelle.\n"
        "• Grille tarifaire officielle à Lomé :\n"
        "  - Zone 1 (Rayon 0 à 3 km - Proximité immédiate) : 1 000 FCFA\n"
        "  - Zone 2 (Rayon 3 à 7 km - Quartiers urbains, ex: Tokoin, Bè, Déckon, Agoè sud) : 1 200 à 1 500 FCFA\n"
        "  - Zone 3 (Rayon > 7 km - Grand Lomé / Périphérie, ex: Baguida, Adétikopé, Zanguéra) : 2 000 FCFA\n\n"
        "• Transparence totale avant paiement : Sur l'écran récapitulatif de validation du panier, le patient voit les deux lignes distinctes :\n"
        "  1. Montant des médicaments : 12 500 FCFA\n"
        "  2. Frais de livraison express : 1 200 FCFA\n"
        "  3. TOTAL PRÉPAYÉ PAR T-MONEY/FLOOZ : 13 700 FCFA\n"
        "Le patient sait exactement ce qu'il paie. Le livreur arrive chez lui sans jamais demander un seul franc supplémentaire."
    )

    # ─────────────────────────────────────────────────────────────
    # QUESTION 2 : LA PHARMACIE OU EDOCTOR ?
    # ─────────────────────────────────────────────────────────────
    h2 = doc.add_paragraph()
    h2.paragraph_format.space_before = Pt(14)
    h2.paragraph_format.space_after = Pt(6)
    r_h2 = h2.add_run("2. Est-ce la pharmacie qui s'occupe de la livraison ou eDoctor ?")
    r_h2.font.name = 'Arial'
    r_h2.font.size = Pt(13)
    r_h2.font.bold = True
    r_h2.font.color.rgb = DARK_NAVY

    p2 = doc.add_paragraph()
    p2.add_run(
        "Au Togo, plus de 85% des officines de pharmacie ne disposent ni de motos, ni de coursiers salariés, ni d'assurance transport.\n"
        "eDoctor propose donc un modèle hybride très avantageux pour les officines :\n\n"
        "Modèle A : Logistique clé en main eDoctor (Modèle par défaut - 90% des cas) :\n"
        "• La pharmacie reçoit la commande sur son portail eDoctor et prépare le paquet scellé avec le nom du patient et le code de commande.\n"
        "• La pharmacie n'a rien à organiser : l'algorithme eDoctor alerte le coursier le plus proche.\n"
        "• Le coursier se présente au comptoir, vérifie le code de commande, récupère le colis scellé et assure l'acheminement.\n\n"
        "Modèle B : Coursier interne de la pharmacie (Optionnel) :\n"
        "• Si une grande officine (ex: Grande Pharmacie du Golfe) emploie déjà un coursier interne, elle peut activer l'option « Livré par nos soins ».\n"
        "• Dans ce cas, la pharmacie encaisse elle-même les frais de livraison payés par le patient."
    )

    # ─────────────────────────────────────────────────────────────
    # QUESTION 3 : COMMENT EDOCTOR TROUVE SES LIVREURS ?
    # ─────────────────────────────────────────────────────────────
    h3 = doc.add_paragraph()
    h3.paragraph_format.space_before = Pt(14)
    h3.paragraph_format.space_after = Pt(6)
    r_h3 = h3.add_run("3. Comment eDoctor recrute et gère ses livreurs ?")
    r_h3.font.name = 'Arial'
    r_h3.font.size = Pt(13)
    r_h3.font.bold = True
    r_h3.font.color.rgb = DARK_NAVY

    p3 = doc.add_paragraph()
    p3.add_run(
        "eDoctor n'a pas besoin d'acheter 50 motos au démarrage. Nous activons 3 filières d'approvisionnement logistique ultra-agiles :\n\n"
        "1. Partenariat B2B avec des flottes de messagerie existantes à Lomé :\n"
        "• Au Togo, il existe déjà des structures professionnelles de livraison express à moto (ex: Tiak-Tiak, Deliver Togo, coursiers Gozem indépendants, agences de courses express).\n"
        "• eDoctor signe une convention B2B avec ces flottes : nous leur apportons du volume garanti de courses régulières, en échange de coursiers rigoureux et disponibles.\n\n"
        "2. Réseau de « Coursiers de Santé eDoctor » Indépendants :\n"
        "• Recrutement direct de jeunes conducteurs de moto rigoureux sur candidature :\n"
        "  - Permis de conduire moto valide (Permis A)\n"
        "  - Moto en parfait état mécanique avec assurance circulation\n"
        "  - Casier judiciaire vierge\n"
        "  - Smartphone Android connecté à Internet 4G\n"
        "• Dotation matérielle eDoctor : Chaque livreur reçoit un badge officiel eDoctor et un sac isotherme étanche et scellé garantissant "
        "la protection des médicaments contre la chaleur tropicale et les intempéries.\n\n"
        "3. Rémunération immédiate et motivante pour le livreur :\n"
        "• Sur une course facturée 1 200 FCFA, le coursier touche 900 FCFA nets (soit 75%).\n"
        "• Le versement est instantané sur son compte T-Money dès que le patient valide la réception du colis grâce au code secret OTP.\n"
        "• Un coursier qui réalise 8 à 10 livraisons par jour gagne ainsi entre 7 000 et 9 000 FCFA nets/jour, ce qui en fait l'un des jobs de coursier les plus attractifs de Lomé."
    )

    # ─────────────────────────────────────────────────────────────
    # QUESTION 4 : SÉCURITÉ DU MÉDICAMENT ET CONFIDENTIALITÉ
    # ─────────────────────────────────────────────────────────────
    h4 = doc.add_paragraph()
    h4.paragraph_format.space_before = Pt(14)
    h4.paragraph_format.space_after = Pt(6)
    r_h4 = h4.add_run("4. Sécurité des Produits de Santé & Secret Médical")
    r_h4.font.name = 'Arial'
    r_h4.font.size = Pt(13)
    r_h4.font.bold = True
    r_h4.font.color.rgb = DARK_NAVY

    p4 = doc.add_paragraph()
    p4.add_run(
        "Le médicament n'est pas une marchandise ordinaire. Pour rassurer l'Ordre des Pharmaciens et les patients, nous appliquons 3 règles d'or :\n"
        "• Colis opaque et inviolable (Tamper-evident) : La pharmacie place les médicaments dans un sachet scellé avec ruban adhésif de sécurité. "
        "Le livreur ne sait jamais quel médicament se trouve à l'intérieur (respect absolu du secret médical et de la vie privée du patient).\n"
        "• Remise sécurisée par Code OTP : Le livreur ne peut pas abandonner le colis devant une porte. Il doit obligatoirement obtenir le code OTP "
        "communiqué par le patient sur son application pour clôturer la livraison sur son interface.\n"
        "• Produits thermosensibles (Chaîne du froid) : Les insulines, collyres ou vaccins sont obligatoirement transportés en pochette isotherme avec accumulateur de froid (gel pack)."
    )

    doc.save(output_path)
    print(f"Document logistique généré : {output_path}")

if __name__ == '__main__':
    target = os.path.join(os.getcwd(), 'GUIDE_LOGISTIQUE_LIVRAISON_PHARMACIE_EDOCTOR.docx')
    create_logistics_guide_docx(target)
