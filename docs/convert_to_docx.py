import os
import re
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

PRIMARY_GREEN = RGBColor(82, 153, 39)     # #529927
DARK_NAVY = RGBColor(19, 42, 69)          # #132A45
TEXT_MUTED = RGBColor(100, 116, 139)      # #64748B
DARK_GRAY = RGBColor(30, 41, 59)          # #1E293B

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

def format_inlines(paragraph, text):
    """Parses bold, italic, and inline code formatting."""
    # Pattern to match **bold**, *italic*, `code`
    tokens = re.split(r'(\*\*.*?\*\*|\*.*?\*|`.*?`)', text)
    for token in tokens:
        if not token:
            continue
        if token.startswith('**') and token.endswith('**') and len(token) >= 4:
            run = paragraph.add_run(token[2:-2])
            run.bold = True
            run.font.color.rgb = DARK_GRAY
        elif token.startswith('*') and token.endswith('*') and len(token) >= 2:
            run = paragraph.add_run(token[1:-1])
            run.italic = True
            run.font.color.rgb = DARK_GRAY
        elif token.startswith('`') and token.endswith('`') and len(token) >= 2:
            run = paragraph.add_run(token[1:-1])
            run.font.name = 'Consolas'
            run.font.size = Pt(9.5)
            run.font.color.rgb = DARK_NAVY
        else:
            run = paragraph.add_run(token)
            run.font.color.rgb = DARK_GRAY

def convert_md_to_docx(md_path, docx_path, doc_title):
    with open(md_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    doc = Document()

    # Set page margins
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        
        # Header & Footer
        header = section.header
        hp = header.paragraphs[0]
        hp.text = f"eDoctor (Togo Health Direct) — {doc_title}"
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        if hp.runs:
            hp.runs[0].font.size = Pt(8.5)
            hp.runs[0].font.color.rgb = TEXT_MUTED

        footer = section.footer
        fp = footer.paragraphs[0]
        fp.text = "eDoctor • Document Métier & Guide Opérationnel Officiel — Usage Interne & Partenaires"
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        if fp.runs:
            fp.runs[0].font.size = Pt(8.5)
            fp.runs[0].font.color.rgb = TEXT_MUTED

    in_code_block = False
    code_lines = []
    in_table = False
    table_rows = []

    def flush_table():
        nonlocal table_rows, in_table
        if not table_rows:
            in_table = False
            return
        
        # Parse table cells
        parsed_rows = []
        for r in table_rows:
            # Skip separator line like |---|---|
            if re.match(r'^\s*\|?\s*:?-+:?\s*\|', r):
                continue
            cells = [c.strip() for c in r.strip().strip('|').split('|')]
            if cells:
                parsed_rows.append(cells)
        
        if parsed_rows:
            num_cols = max(len(row) for row in parsed_rows)
            table = doc.add_table(rows=len(parsed_rows), cols=num_cols)
            table.alignment = WD_TABLE_ALIGNMENT.CENTER
            table.autofit = True

            for r_idx, row_data in enumerate(parsed_rows):
                row = table.rows[r_idx]
                is_header = (r_idx == 0)
                for c_idx in range(num_cols):
                    cell = row.cells[c_idx]
                    text = row_data[c_idx] if c_idx < len(row_data) else ""
                    cell.text = ""
                    p = cell.paragraphs[0]
                    p.paragraph_format.space_before = Pt(4)
                    p.paragraph_format.space_after = Pt(4)
                    p.paragraph_format.line_spacing = 1.15
                    format_inlines(p, text)

                    if is_header:
                        set_cell_background(cell, "132A45") # Dark navy
                        for run in p.runs:
                            run.font.bold = True
                            run.font.color.rgb = RGBColor(255, 255, 255)
                    else:
                        bg = "F8FAFC" if (r_idx % 2 == 1) else "FFFFFF"
                        set_cell_background(cell, bg)
                    
                    set_cell_margins(cell, top=120, bottom=120, left=150, right=150)

            # Spacing after table
            p_space = doc.add_paragraph()
            p_space.paragraph_format.space_before = Pt(4)
            p_space.paragraph_format.space_after = Pt(8)

        table_rows = []
        in_table = False

    def flush_code():
        nonlocal code_lines, in_code_block
        if not code_lines:
            in_code_block = False
            return
        
        table = doc.add_table(rows=1, cols=1)
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        cell = table.rows[0].cells[0]
        set_cell_background(cell, "F1F5F9")
        set_cell_margins(cell, top=140, bottom=140, left=200, right=200)
        
        cp = cell.paragraphs[0]
        cp.paragraph_format.space_before = Pt(2)
        cp.paragraph_format.space_after = Pt(2)
        cp.paragraph_format.line_spacing = 1.15
        
        code_text = "".join(code_lines)
        run = cp.add_run(code_text.strip())
        run.font.name = 'Consolas'
        run.font.size = Pt(9.0)
        run.font.color.rgb = RGBColor(30, 41, 59)

        p_space = doc.add_paragraph()
        p_space.paragraph_format.space_after = Pt(6)

        code_lines = []
        in_code_block = False

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Handle code blocks
        if stripped.startswith('```'):
            if in_code_block:
                flush_code()
            else:
                if in_table:
                    flush_table()
                in_code_block = True
                code_lines = []
            i += 1
            continue

        if in_code_block:
            code_lines.append(line)
            i += 1
            continue

        # Handle tables
        if stripped.startswith('|') and stripped.endswith('|'):
            if not in_table:
                in_table = True
                table_rows = []
            table_rows.append(stripped)
            i += 1
            continue
        else:
            if in_table:
                flush_table()

        # Empty lines
        if not stripped:
            i += 1
            continue

        # Horizontal rule
        if stripped in ['---', '***', '___']:
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(6)
            p.paragraph_format.space_after = Pt(12)
            run = p.add_run("―" * 55)
            run.font.color.rgb = RGBColor(203, 213, 225)
            i += 1
            continue

        # Heading 1 (# )
        if stripped.startswith('# '):
            title_text = stripped[2:].strip()
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(16)
            p.paragraph_format.space_after = Pt(8)
            p.paragraph_format.keep_with_next = True
            run = p.add_run(title_text)
            run.font.name = 'Arial'
            run.font.size = Pt(20)
            run.font.bold = True
            run.font.color.rgb = PRIMARY_GREEN
            i += 1
            continue

        # Heading 2 (## )
        if stripped.startswith('## '):
            h2_text = stripped[3:].strip()
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(14)
            p.paragraph_format.space_after = Pt(6)
            p.paragraph_format.keep_with_next = True
            run = p.add_run(h2_text)
            run.font.name = 'Arial'
            run.font.size = Pt(14)
            run.font.bold = True
            run.font.color.rgb = DARK_NAVY
            i += 1
            continue

        # Heading 3 (### )
        if stripped.startswith('### '):
            h3_text = stripped[4:].strip()
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(10)
            p.paragraph_format.space_after = Pt(4)
            p.paragraph_format.keep_with_next = True
            run = p.add_run(h3_text)
            run.font.name = 'Arial'
            run.font.size = Pt(12)
            run.font.bold = True
            run.font.color.rgb = PRIMARY_GREEN
            i += 1
            continue

        # Heading 4 (#### )
        if stripped.startswith('#### '):
            h4_text = stripped[5:].strip()
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(8)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.keep_with_next = True
            run = p.add_run(h4_text)
            run.font.name = 'Arial'
            run.font.size = Pt(11)
            run.font.bold = True
            run.font.color.rgb = DARK_NAVY
            i += 1
            continue

        # Blockquote (> )
        if stripped.startswith('> '):
            quote_text = stripped[2:].strip()
            table = doc.add_table(rows=1, cols=1)
            table.alignment = WD_TABLE_ALIGNMENT.CENTER
            cell = table.rows[0].cells[0]
            set_cell_background(cell, "F0FDF4") # Light soft green
            set_cell_margins(cell, top=100, bottom=100, left=180, right=180)
            
            qp = cell.paragraphs[0]
            qp.paragraph_format.space_before = Pt(2)
            qp.paragraph_format.space_after = Pt(2)
            format_inlines(qp, quote_text)
            for r in qp.runs:
                r.font.size = Pt(10)
                r.italic = True
            
            p_space = doc.add_paragraph()
            p_space.paragraph_format.space_after = Pt(4)
            i += 1
            continue

        # Bullet list items (- or * or •)
        if stripped.startswith('- ') or stripped.startswith('* '):
            item_text = stripped[2:].strip()
            p = doc.add_paragraph(style='List Bullet')
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.15
            format_inlines(p, item_text)
            i += 1
            continue

        # Numbered list items (1. , 2. )
        m_num = re.match(r'^(\d+)\.\s+(.*)$', stripped)
        if m_num:
            item_text = m_num.group(2).strip()
            p = doc.add_paragraph(style='List Number')
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(2)
            p.paragraph_format.line_spacing = 1.15
            format_inlines(p, item_text)
            i += 1
            continue

        # Standard paragraph
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(5)
        p.paragraph_format.line_spacing = 1.15
        format_inlines(p, stripped)
        i += 1

    if in_table:
        flush_table()
    if in_code_block:
        flush_code()

    doc.save(docx_path)
    print(f"Successfully generated: {docx_path}")

def main():
    docs_dir = r"c:\Users\belou\Documents\edoctor\docs"
    files = [
        ("01_DOCUMENT_METIER_ET_REGLES_DE_GESTION.md", "01_DOCUMENT_METIER_ET_REGLES_DE_GESTION.docx", "Spécifications Métier"),
        ("02_MANUEL_UTILISATEUR_PATIENT.md", "02_MANUEL_UTILISATEUR_PATIENT.docx", "Guide Patient"),
        ("03_MANUEL_UTILISATEUR_PRATICIEN_ET_HOPITAL.md", "03_MANUEL_UTILISATEUR_PRATICIEN_ET_HOPITAL.docx", "Manuel Praticien & Hôpital"),
        ("04_MANUEL_UTILISATEUR_PHARMACIE_ET_OFFICINE.md", "04_MANUEL_UTILISATEUR_PHARMACIE_ET_OFFICINE.docx", "Manuel Pharmacie & Stocks"),
        ("README.md", "SOMMAIRE_GENERAL_DOCUMENTATION.docx", "Sommaire Général"),
    ]

    for md_name, docx_name, title in files:
        md_file = os.path.join(docs_dir, md_name)
        docx_file = os.path.join(docs_dir, docx_name)
        if os.path.exists(md_file):
            print(f"Converting {md_name} -> {docx_name}...")
            convert_md_to_docx(md_file, docx_file, title)
        else:
            print(f"File not found: {md_file}")

if __name__ == "__main__":
    main()
