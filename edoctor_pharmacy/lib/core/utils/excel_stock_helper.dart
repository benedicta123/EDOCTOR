import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../data/models/stock_item_model.dart';

class ExcelStockHelper {
  ExcelStockHelper._();

  /// Convertit les octets d'un fichier Excel (.xlsx / .xls) en chaîne CSV (séparateur point-virgule).
  /// Permet d'importer directement n'importe quel fichier Excel dans l'API.
  static String excelBytesToCsv(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('Le fichier Excel ne contient aucune feuille valide.');
    }

    // Sélectionne la première feuille non-vide
    Sheet? targetSheet;
    for (final tableName in excel.tables.keys) {
      final s = excel.tables[tableName];
      if (s != null && s.rows.isNotEmpty) {
        targetSheet = s;
        break;
      }
    }

    if (targetSheet == null || targetSheet.rows.isEmpty) {
      throw Exception('La feuille Excel est vide.');
    }

    final StringBuffer csvBuffer = StringBuffer();

    for (final row in targetSheet.rows) {
      // Vérifie si la ligne contient au moins une cellule non vide
      final hasData = row.any((c) => c != null && c.value != null && c.value.toString().trim().isNotEmpty);
      if (!hasData) continue;

      final cellStrings = row.map((cell) {
        if (cell == null || cell.value == null) return '';
        final val = cell.value;
        String rawStr = '';

        if (val is TextCellValue) {
          rawStr = val.value.text ?? '';
        } else if (val is IntCellValue) {
          rawStr = val.value.toString();
        } else if (val is DoubleCellValue) {
          rawStr = val.value.toString();
        } else if (val is BoolCellValue) {
          rawStr = val.value ? 'oui' : 'non';
        } else if (val is DateCellValue) {
          rawStr = val.asDateTimeLocal().toIso8601String().substring(0, 10);
        } else {
          rawStr = val.toString();
        }

        // Nettoie la valeur et échappe si nécessaire
        rawStr = rawStr.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
        if (rawStr.contains(';') || rawStr.contains('"')) {
          rawStr = '"${rawStr.replaceAll('"', '""')}"';
        }
        return rawStr;
      }).toList();

      csvBuffer.writeln(cellStrings.join(';'));
    }

    final result = csvBuffer.toString();
    if (result.trim().isEmpty) {
      throw Exception('Aucune donnée valide trouvée dans le fichier Excel.');
    }
    return result;
  }

  /// Génère un fichier Excel (.xlsx) complet et stylisé pour l'export de l'inventaire officiel.
  static Uint8List generateStocksExcelBytes({
    required List<StockItemModel> stocks,
    required String pharmacyName,
  }) {
    final excel = Excel.createExcel();
    // Renomme ou remplace la première feuille
    const sheetName = 'Inventaire Stocks';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // Supprime la feuille Sheet1 créée par défaut si différente
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    // 1. En-tête officiel
    sheet.appendRow([
      TextCellValue('INVENTAIRE OFFICIEL DES STOCKS — EDOCTOR'),
    ]);
    sheet.appendRow([
      TextCellValue('Pharmacie : $pharmacyName'),
    ]);
    final dateFormatted = DateTime.now().toLocal().toString().substring(0, 16);
    sheet.appendRow([
      TextCellValue('Date d\'exportation : $dateFormatted • Devise : Franc CFA (FCFA)'),
    ]);
    sheet.appendRow([]); // Ligne vide de séparation

    // 2. En-têtes du tableau
    sheet.appendRow([
      TextCellValue('ID Médicament'),
      TextCellValue('Nom Médicament'),
      TextCellValue('Dosage'),
      TextCellValue('Forme Galénique'),
      TextCellValue('Catégorie Thérapeutique'),
      TextCellValue('Quantité en Stock'),
      TextCellValue('Prix Unitaire (FCFA)'),
      TextCellValue('Valeur Totale Stock (FCFA)'),
      TextCellValue('Statut Stock'),
      TextCellValue('Sur Ordonnance'),
    ]);

    // 3. Données des médicaments
    int totalUnits = 0;
    double totalValuation = 0.0;

    for (final item in stocks) {
      final totalValue = item.quantity * item.price;
      totalUnits += item.quantity;
      totalValuation += totalValue;

      String statusStr = 'En stock';
      if (item.status == StockStatus.outOfStock) {
        statusStr = 'Rupture';
      } else if (item.status == StockStatus.lowStock) {
        statusStr = 'Stock faible';
      }

      sheet.appendRow([
        IntCellValue(item.medicationId),
        TextCellValue(item.medicationName),
        TextCellValue(item.dosage ?? '-'),
        TextCellValue(item.form ?? 'Comprimé'),
        TextCellValue(item.category ?? 'Général'),
        IntCellValue(item.quantity),
        IntCellValue(item.price.toInt()),
        IntCellValue(totalValue.toInt()),
        TextCellValue(statusStr),
        TextCellValue(item.requiresPrescription ? 'Oui' : 'Non'),
      ]);
    }

    // 4. Ligne de récapitulatif total
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('TOTAL INVENTAIRE'),
      TextCellValue('${stocks.length} références'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      IntCellValue(totalUnits),
      TextCellValue(''),
      IntCellValue(totalValuation.toInt()),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Échec de la génération du fichier Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  /// Génère le modèle de fichier Excel (.xlsx) téléchargeable par l'officine.
  static Uint8List generateTemplateExcelBytes() {
    final excel = Excel.createExcel();
    const sheetName = 'Modèle Import Stocks';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // En-têtes
    sheet.appendRow([
      TextCellValue('nom_medicament'),
      TextCellValue('dosage'),
      TextCellValue('forme'),
      TextCellValue('categorie'),
      TextCellValue('quantite'),
      TextCellValue('prix_fcfa'),
      TextCellValue('sur_ordonnance'),
    ]);

    // Données d'exemple
    final examples = [
      ['Paracétamol Biogaran', '500mg', 'Comprimé', 'Antalgique / Antipyrétique', 150, 500, 'non'],
      ['Coartem (Artéméther / Luméfantrine)', '20/120mg', 'Comprimé', 'Antipaludique', 120, 2200, 'non'],
      ['Amoxicilline Teva', '500mg', 'Gélule', 'Antibiotique', 90, 1500, 'oui'],
      ['Ibuprofène Mylan', '400mg', 'Comprimé', 'Anti-inflammatoire', 110, 1100, 'non'],
      ['Augmentin', '1g/125mg', 'Poudre suspension', 'Antibiotique', 45, 4800, 'oui'],
      ['Vitamine C UPSA', '1000mg', 'Comprimé à croquer', 'Vitamines', 200, 850, 'non'],
      ['Spasfon', '80mg', 'Comprimé lyophilisé', 'Antispasmodique', 75, 1750, 'non'],
      ['Sérum Physiologique Gilbert', '0.9% 500ml', 'Flacon', 'Soluté', 50, 950, 'non'],
      ['Oméprazole Biogaran', '20mg', 'Gélule', 'Gastro-entérologie', 65, 2400, 'non'],
      ['Bétadine Dermique', '10% 125ml', 'Flacon', 'Antiseptique local', 40, 1600, 'non'],
    ];

    for (final row in examples) {
      sheet.appendRow([
        TextCellValue(row[0] as String),
        TextCellValue(row[1] as String),
        TextCellValue(row[2] as String),
        TextCellValue(row[3] as String),
        IntCellValue(row[4] as int),
        IntCellValue(row[5] as int),
        TextCellValue(row[6] as String),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Échec de la génération du modèle Excel.');
    }
    return Uint8List.fromList(bytes);
  }
}
