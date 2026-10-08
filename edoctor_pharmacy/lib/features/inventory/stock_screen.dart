import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/excel_stock_helper.dart';
import '../../core/utils/file_download_helper.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pharmacy_shell.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/stock_item_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/pharmacy_model.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  UserModel? _user;
  PharmacyModel? _pharmacy;
  List<StockItemModel> _stocks = [];
  bool _loading = true;
  String _searchQuery = '';
  String _statusFilter = 'tous';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final pharmacy = await ApiService.getMyPharmacy();
      final stocks = await ApiService.getStocks(pharmacy.id);

      if (mounted) {
        setState(() {
          _user = user;
          _pharmacy = pharmacy;
          _stocks = stocks;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.outOfStock,
          ),
        );
      }
    }
  }

  List<StockItemModel> get _filteredStocks {
    return _stocks.where((item) {
      final matchesSearch = item.medicationName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.dosage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (item.category?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      if (!matchesSearch) return false;

      if (_statusFilter == 'inStock') {
        return item.status == StockStatus.inStock;
      }
      if (_statusFilter == 'lowStock') {
        return item.status == StockStatus.lowStock;
      }
      if (_statusFilter == 'outOfStock') {
        return item.status == StockStatus.outOfStock;
      }
      return true;
    }).toList();
  }

  Future<void> _editStock(StockItemModel item) async {
    final qtyController = TextEditingController(text: item.quantity.toString());
    final priceController = TextEditingController(text: item.price.toInt().toString());

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.medicationName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.dosage != null)
              Text('Dosage : ${item.dosage}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantité en stock (boîtes)',
                prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prix unitaire (FCFA)',
                prefixIcon: Icon(Icons.payments_outlined, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newQty = int.tryParse(qtyController.text) ?? item.quantity;
              final newPrice = double.tryParse(priceController.text) ?? item.price;
              try {
                await ApiService.storeOrUpdateStock(
                  pharmacyId: item.pharmacyId,
                  medicationId: item.medicationId,
                  quantity: newQty,
                  price: newPrice,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: AppColors.outOfStock,
                    ),
                  );
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (updated == true) {
      _load();
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final template = await ApiService.getStockTemplate();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.description_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Modèle de fichier CSV', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Utilisez ce modèle pour préparer vos stocks dans Excel ou votre logiciel de gestion (séparateur point-virgule) :',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    template,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Colonnes prises en charge : "nom_medicament", "dosage", "forme", "quantite", "prix_fcfa", "sur_ordonnance".',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryHover),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Modèle CSV (.csv)'),
              onPressed: () async {
                Navigator.pop(ctx);
                final bytes = Uint8List.fromList(utf8.encode(template));
                await FileDownloadHelper.download(
                  bytes: bytes,
                  filename: 'modele_import_stocks_edoctor.csv',
                  mimeType: 'text/csv;charset=utf-8',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Modèle CSV téléchargé avec succès !'),
                      backgroundColor: AppColors.inStock,
                    ),
                  );
                }
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.table_view_rounded, size: 16),
              label: const Text('Modèle Excel (.xlsx)'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF107C41)),
              onPressed: () async {
                Navigator.pop(ctx);
                final bytes = ExcelStockHelper.generateTemplateExcelBytes();
                await FileDownloadHelper.download(
                  bytes: bytes,
                  filename: 'modele_import_stocks_edoctor.xlsx',
                  mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Modèle Excel (.xlsx) téléchargé avec succès !'),
                      backgroundColor: AppColors.inStock,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.outOfStock),
        );
      }
    }
  }

  Future<void> _exportStocksExcel() async {
    final pharmacy = _pharmacy;
    if (pharmacy == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Génération du classeur Excel (.xlsx) en cours...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final bytes = ExcelStockHelper.generateStocksExcelBytes(
        stocks: _stocks,
        pharmacyName: pharmacy.name,
      );
      final safeName = pharmacy.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final filename = 'inventaire_${safeName}_$dateStr.xlsx';

      await FileDownloadHelper.download(
        bytes: bytes,
        filename: filename,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Inventaire Excel exporté avec succès ($filename) !'),
            backgroundColor: AppColors.inStock,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.outOfStock,
          ),
        );
      }
    }
  }

  Future<void> _showImportDialog() async {
    final pharmacy = _pharmacy;
    if (pharmacy == null) return;

    PlatformFile? selectedFile;
    String? fileContent;
    bool isProcessing = false;
    String? resultMessage;
    bool hasError = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.upload_file_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Importer les stocks (Excel / CSV)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Chargez votre fichier d\'inventaire (.xlsx, .xls ou .csv) exporté depuis votre logiciel de gestion pharmaceutique pour mettre à jour tous vos stocks en une seule fois.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // Zone de sélection du fichier
                  InkWell(
                    onTap: isProcessing
                        ? null
                        : () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
                              withData: true,
                            );

                            if (result != null && result.files.isNotEmpty) {
                              final f = result.files.first;
                              final bytes = f.bytes;
                              if (bytes != null) {
                                final ext = (f.extension ?? '').toLowerCase();
                                if (ext == 'xlsx' || ext == 'xls') {
                                  try {
                                    final csvConverted = ExcelStockHelper.excelBytesToCsv(bytes);
                                    setModalState(() {
                                      selectedFile = f;
                                      fileContent = csvConverted;
                                      resultMessage = null;
                                      hasError = false;
                                    });
                                  } catch (err) {
                                    setModalState(() {
                                      selectedFile = f;
                                      fileContent = null;
                                      hasError = true;
                                      resultMessage = 'Erreur de lecture du classeur Excel : ${err.toString().replaceFirst("Exception: ", "")}';
                                    });
                                  }
                                } else {
                                  try {
                                    final content = utf8.decode(bytes);
                                    setModalState(() {
                                      selectedFile = f;
                                      fileContent = content;
                                      resultMessage = null;
                                      hasError = false;
                                    });
                                  } catch (_) {
                                    // Fallback latin1 si encodage Windows/Excel non UTF-8
                                    final content = latin1.decode(bytes);
                                    setModalState(() {
                                      selectedFile = f;
                                      fileContent = content;
                                      resultMessage = null;
                                      hasError = false;
                                    });
                                  }
                                }
                              }
                            }
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: selectedFile != null ? AppColors.primaryContainer.withValues(alpha: 0.3) : AppColors.surfaceDim,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedFile != null ? AppColors.primary : AppColors.border,
                          width: selectedFile != null ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                            size: 38,
                            color: selectedFile != null ? AppColors.primary : AppColors.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            selectedFile != null ? selectedFile!.name : 'Cliquez pour sélectionner un fichier Excel (.xlsx, .xls) ou CSV',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selectedFile != null ? AppColors.primaryHover : AppColors.textPrimary,
                            ),
                          ),
                          if (selectedFile != null) ...[
                            const SizedBox(height: 4),
                            Builder(
                              builder: (_) {
                                int detected = 0;
                                if (fileContent != null) {
                                  final lines = fileContent!.split(RegExp(r'\r\n|\r|\n')).where((l) => l.trim().isNotEmpty).toList();
                                  detected = lines.length > 1 ? lines.length - 1 : (lines.isNotEmpty ? 1 : 0);
                                }
                                return Text(
                                  'Taille : ${(selectedFile!.size / 1024).toStringAsFixed(1)} Ko • $detected article(s) prêt(s) à être importé(s)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Message de résultat ou barre de chargement
                  if (isProcessing) ...[
                    const SizedBox(height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                        SizedBox(width: 12),
                        Text('Importation des stocks en cours...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],

                  if (resultMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasError ? AppColors.outOfStockLight : AppColors.inStockLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                            color: hasError ? AppColors.outOfStock : AppColors.inStock,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              resultMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: hasError ? AppColors.outOfStock : AppColors.inStock,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text('Lancer l\'importation'),
                onPressed: (selectedFile == null || fileContent == null || isProcessing)
                    ? null
                    : () async {
                        setModalState(() {
                          isProcessing = true;
                          resultMessage = null;
                        });

                        try {
                          final res = await ApiService.importStocksCsv(
                            pharmacyId: pharmacy.id,
                            csvContent: fileContent!,
                          );

                          final total = res['total_processed'] ?? 0;
                          final newMeds = res['new_medications'] ?? 0;
                          final updated = res['updated_stocks'] ?? 0;

                          setModalState(() {
                            isProcessing = false;
                            hasError = false;
                            resultMessage = '✅ $total article(s) importé(s) : $updated stocks mis à jour, $newMeds nouveau(x) médicament(s) ajouté(s).';
                          });

                          _load();
                        } catch (e) {
                          setModalState(() {
                            isProcessing = false;
                            hasError = true;
                            resultMessage = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PharmacyShell(
      currentSection: PharmacySection.inventory,
      title: 'Gestion des stocks',
      user: _user,
      pharmacy: _pharmacy,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête : Actions d'importation & Modèle CSV
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Catalogue & Disponibilité',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.description_outlined, size: 16),
                            label: const Text('Modèle Excel / CSV'),
                            onPressed: _downloadTemplate,
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.table_view_rounded, size: 16),
                            label: const Text('Exporter l\'inventaire (Excel)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF107C41),
                              side: const BorderSide(color: Color(0xFF107C41)),
                            ),
                            onPressed: _exportStocksExcel,
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Importer un fichier (Excel / CSV)'),
                            onPressed: _showImportDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Barre de recherche et filtres
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Rechercher un médicament, dosage ou molécule...',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Wrap(
                        spacing: 8,
                        children: [
                          _filterChip('tous', 'Tous (${_stocks.length})'),
                          _filterChip('inStock', 'En stock (${_stocks.where((s) => s.status == StockStatus.inStock).length})'),
                          _filterChip('lowStock', 'Stock faible (${_stocks.where((s) => s.status == StockStatus.lowStock).length})'),
                          _filterChip('outOfStock', 'Ruptures (${_stocks.where((s) => s.status == StockStatus.outOfStock).length})'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Liste des médicaments
                  Expanded(
                    child: _filteredStocks.isEmpty
                        ? const EmptyStateView(
                            icon: Icons.inventory_2_outlined,
                            title: 'Aucun médicament trouvé',
                            message: 'Modifiez vos critères de recherche ou réapprovisionnez votre catalogue.',
                          )
                        : ListView.separated(
                            itemCount: _filteredStocks.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final item = _filteredStocks[idx];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceDim,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 22),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  item.medicationName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                if (item.requiresPrescription) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primaryContainer,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'Sur ordonnance',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors.primaryHover,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.dosage ?? 'Dosage standard'} • ${item.form ?? 'Comprimé'} • Prix : ${Formatters.currency(item.price)}',
                                              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${item.quantity} boîte(s)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: item.status == StockStatus.outOfStock
                                                  ? AppColors.outOfStock
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          StockBadge(status: item.status),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      OutlinedButton(
                                        onPressed: () => _editStock(item),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        ),
                                        child: const Text('Mettre à jour'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      onSelected: (_) => setState(() => _statusFilter = key),
    );
  }
}
