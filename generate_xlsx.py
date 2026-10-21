import zipfile
import io

def create_simple_xlsx(filename, rows):
    """
    Creates a valid Excel (.xlsx) file using only standard python zipfile and XML.
    rows: list of lists of strings/numbers
    """
    content_types = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>"""

    rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>"""

    workbook_rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>"""

    workbook = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Stocks Medicaments" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>"""

    styles = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><name val="Calibri"/><sz val="11"/></font>
    <font><b/><name val="Calibri"/><sz val="11"/><color rgb="FFFFFFFF"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF132A45"/></patternFill></fill>
  </fills>
  <borders count="1"><border><left/><right/><top/><bottom/></border></borders>
  <cellStyleXfs count="1"><xf/></cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
  </cellXfs>
</styleSheet>"""

    sheet_rows_xml = []
    for r_idx, row in enumerate(rows, 1):
        row_cells = []
        is_header = (r_idx == 1)
        style_attr = ' s="1"' if is_header else ''
        for c_idx, val in enumerate(row):
            col_letter = chr(65 + c_idx)
            cell_ref = f"{col_letter}{r_idx}"
            if isinstance(val, (int, float)):
                cell_xml = f'<c r="{cell_ref}"{style_attr}><v>{val}</v></c>'
            else:
                str_val = str(val).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                cell_xml = f'<c r="{cell_ref}" t="inlineStr"{style_attr}><is><t>{str_val}</t></is></c>'
            row_cells.append(cell_xml)
        sheet_rows_xml.append(f'<row r="{r_idx}">{"".join(row_cells)}</row>')

    sheet1 = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    {"".join(sheet_rows_xml)}
  </sheetData>
</worksheet>"""

    with zipfile.ZipFile(filename, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", content_types)
        z.writestr("_rels/.rels", rels)
        z.writestr("xl/workbook.xml", workbook)
        z.writestr("xl/_rels/workbook.xml.rels", workbook_rels)
        z.writestr("xl/styles.xml", styles)
        z.writestr("xl/worksheets/sheet1.xml", sheet1)

    print(f"Excel file created: {filename}")

data = [
    ["nom_medicament", "dosage", "forme", "categorie", "quantite", "prix_fcfa", "sur_ordonnance"],
    ["Paracétamol Biogaran", "500mg", "Comprimé", "Antalgique / Antipyrétique", 150, 500, "non"],
    ["Coartem (Artéméther / Luméfantrine)", "20/120mg", "Comprimé", "Antipaludique", 120, 2200, "non"],
    ["Amoxicilline Teva", "500mg", "Gélule", "Antibiotique", 90, 1500, "oui"],
    ["Ibuprofène Mylan", "400mg", "Comprimé", "Anti-inflammatoire", 110, 1100, "non"],
    ["Augmentin", "1g/125mg", "Poudre suspension", "Antibiotique", 45, 4800, "oui"],
    ["Vitamine C UPSA", "1000mg", "Comprimé à croquer", "Vitamines", 200, 850, "non"],
    ["Spasfon", "80mg", "Comprimé lyophilisé", "Antispasmodique", 75, 1750, "non"],
    ["Sérum Physiologique Gilbert", "0.9% 500ml", "Flacon", "Soluté", 50, 950, "non"],
    ["Oméprazole Biogaran", "20mg", "Gélule", "Gastro-entérologie", 65, 2400, "non"],
    ["Bétadine Dermique", "10% 125ml", "Flacon", "Antiseptique", 40, 1600, "non"]
]

create_simple_xlsx(r"c:\Users\belou\Documents\edoctor\test_import_stocks_pharmacie.xlsx", data)
create_simple_xlsx(r"c:\Users\belou\Documents\edoctor\docs\test_import_stocks_pharmacie.xlsx", data)
