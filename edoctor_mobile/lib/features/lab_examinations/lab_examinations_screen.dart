import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/lab_order_pdf_service.dart';
import '../../core/widgets/patient_bottom_nav.dart';
import '../../data/models/lab_request_model.dart';

class LabExaminationsScreen extends StatefulWidget {
  final int? autoOpenLabId;

  const LabExaminationsScreen({super.key, this.autoOpenLabId});

  @override
  State<LabExaminationsScreen> createState() => _LabExaminationsScreenState();
}

class _LabExaminationsScreenState extends State<LabExaminationsScreen> {
  bool _loading = true;
  String? _error;
  List<LabRequestModel> _allLabs = [];
  String _selectedFilter = 'all'; // 'all', 'pending', 'transmitted', 'completed'

  @override
  void initState() {
    super.initState();
    _loadLabs();
  }

  Future<void> _loadLabs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final labs = await ApiService.getMyLabRequests();
      if (!mounted) return;
      setState(() {
        _allLabs = labs;
        _loading = false;
      });

      if (widget.autoOpenLabId != null) {
        final target = _allLabs.where((l) => l.id == widget.autoOpenLabId).firstOrNull;
        if (target != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openUploadSheet(target);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<LabRequestModel> get _filteredLabs {
    switch (_selectedFilter) {
      case 'pending':
        return _allLabs
            .where((l) => l.status == 'prescrit' || l.status == 'en_attente_resultats')
            .toList();
      case 'transmitted':
        return _allLabs.where((l) => l.status == 'resultats_recus').toList();
      case 'completed':
        return _allLabs.where((l) => l.status == 'analyse_terminee').toList();
      case 'all':
      default:
        return _allLabs;
    }
  }

  void _openUploadSheet(LabRequestModel lab) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UploadLabResultsSheet(
        labRequest: lab,
        onSuccess: () {
          _loadLabs();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Résultats transmis au médecin avec succès !'),
            ),
          );
        },
      ),
    );
  }

  void _openResultPreview(LabRequestResultModel result) {
    showDialog(
      context: context,
      builder: (ctx) => _ResultPreviewDialog(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        title: const Text(
          'Mes Bilans & Examens',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLabs,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      bottomNavigationBar: PatientBottomNav(
        currentIndex: -1,
        onTabSelected: (idx) {
          if (idx == 0) {
            Navigator.of(context).pushReplacementNamed('/home');
          } else if (idx == 1) {
            Navigator.of(context).pushReplacementNamed('/doctors');
          } else if (idx == 2) {
            Navigator.of(context).pushReplacementNamed('/dossier');
          } else if (idx == 3) {
            Navigator.of(context).pushReplacementNamed('/profile');
          }
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadLabs,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildFilterTabs(),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadLabs,
                        child: _filteredLabs.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: _filteredLabs.length,
                                itemBuilder: (ctx, idx) => _buildLabCard(_filteredLabs[idx]),
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'key': 'all', 'label': 'Tous (${_allLabs.length})'},
      {
        'key': 'pending',
        'label': 'À réaliser (${_allLabs.where((l) => l.status == 'prescrit' || l.status == 'en_attente_resultats').length})',
      },
      {
        'key': 'transmitted',
        'label': 'Transmis (${_allLabs.where((l) => l.status == 'resultats_recus').length})',
      },
      {
        'key': 'completed',
        'label': 'Validés (${_allLabs.where((l) => l.status == 'analyse_terminee').length})',
      },
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isSelected = _selectedFilter == f['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                label: Text(f['label']!),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
                onSelected: (_) => setState(() => _selectedFilter = f['key']!),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.biotech_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun bilan d’examen pour ce filtre',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Lorsqu’un médecin vous prescrira des analyses ou que vous aurez transmis vos résultats, ils apparaîtront ici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabCard(LabRequestModel lab) {
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (lab.status) {
      case 'resultats_recus':
        statusColor = const Color(0xFF0284C7);
        statusBg = const Color(0xFFE0F2FE);
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'analyse_terminee':
        statusColor = AppColors.success;
        statusBg = AppColors.successLight;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'en_attente_resultats':
      case 'prescrit':
      default:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        statusIcon = Icons.assignment_late_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lab.status == 'resultats_recus'
              ? const Color(0xFF0284C7).withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Entête carte
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        lab.referenceCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (lab.isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    if (lab.fastingRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'À JEUN',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            lab.statusDisplayLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      lab.doctorName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(' · ', style: TextStyle(color: Colors.grey)),
                    Expanded(
                      child: Text(
                        lab.hospitalName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Prescrit le ${lab.formattedDate}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Analyses demandées :',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: lab.items.map((it) {
                    final isImaging = it.category == 'imagerie';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isImaging ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isImaging ? Icons.image_rounded : Icons.science_rounded,
                            size: 13,
                            color: isImaging ? const Color(0xFF7E22CE) : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            it.name,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isImaging ? const Color(0xFF6B21A8) : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (lab.clinicalNotes != null && lab.clinicalNotes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAF7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Indication : ${lab.clinicalNotes}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Résultats téléversés
                if (lab.hasResults) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Documents & photos transmis :',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: lab.results.map((res) {
                      return InkWell(
                        onTap: () => _openResultPreview(res),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                res.isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                                size: 16,
                                color: const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                res.fileName,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.remove_red_eye_rounded, size: 14, color: Color(0xFF0284C7)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                // Conclusions du praticien
                if (lab.doctorReviewNotes != null && lab.doctorReviewNotes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.successLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text(
                              'Conclusions du ${lab.doctorName} :',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lab.doctorReviewNotes!,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Barre d'actions inférieure
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => LabOrderPdfService.printLabOrder(lab),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text(
                      'Ordonnance PDF',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lab.hasResults ? const Color(0xFF0284C7) : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _openUploadSheet(lab),
                    icon: Icon(
                      lab.hasResults ? Icons.add_photo_alternate_rounded : Icons.cloud_upload_rounded,
                      size: 16,
                    ),
                    label: Text(
                      lab.hasResults ? 'Ajouter doc' : 'Transmettre',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille de téléversement de résultats pour le patient
class _UploadLabResultsSheet extends StatefulWidget {
  final LabRequestModel labRequest;
  final VoidCallback onSuccess;

  const _UploadLabResultsSheet({
    required this.labRequest,
    required this.onSuccess,
  });

  @override
  State<_UploadLabResultsSheet> createState() => _UploadLabResultsSheetState();
}

class _UploadLabResultsSheetState extends State<_UploadLabResultsSheet> {
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  // Document simulé ou sélectionné
  String? _selectedDocumentName;
  String? _selectedDocumentBase64;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _selectDocument(String name, String type) {
    // Échantillon de document d'analyses encodé (1px transparent ou badge standard)
    const mockImageBase64 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    setState(() {
      _selectedDocumentName = name;
      _selectedDocumentBase64 = mockImageBase64;
    });
  }

  Future<void> _submit() async {
    if (_selectedDocumentBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Veuillez sélectionner ou prendre en photo le document de résultats.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.uploadLabResults(
        widget.labRequest.id,
        patientNotes: _notesCtrl.text.trim(),
        fileBase64: _selectedDocumentBase64,
        fileName: _selectedDocumentName ?? 'feuille_resultat_analyses.jpg',
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transmettre mes résultats d’analyses',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Bilan ${widget.labRequest.referenceCode}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Comment souhaitez-vous joindre vos résultats ?',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  // Options de sélection de document
                  Row(
                    children: [
                      Expanded(
                        child: _buildSourceButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Prendre une photo\nde la feuille',
                          onTap: () => _selectDocument('Photo_Resultats_${DateTime.now().millisecondsSinceEpoch}.jpg', 'photo'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSourceButton(
                          icon: Icons.picture_as_pdf_rounded,
                          label: 'Joindre un scan\nou fichier PDF',
                          onTap: () => _selectDocument('Compte_Rendu_Labo_${DateTime.now().millisecondsSinceEpoch}.pdf', 'pdf'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_selectedDocumentName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.successLight.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedDocumentName!,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const Text(
                                  'Document prêt pour l’envoi sécurisé',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                            onPressed: () => setState(() {
                              _selectedDocumentName = null;
                              _selectedDocumentBase64 = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Notes ou précisions pour le médecin (facultatif) :',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Prélèvement réalisé au laboratoire Saint-Joseph ce matin. Résultat reçu par email.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text(
                            'Envoyer au médecin',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu d'un résultat en plein écran
class _ResultPreviewDialog extends StatelessWidget {
  final LabRequestResultModel result;

  const _ResultPreviewDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF132A45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.fileName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Container(
                  color: Colors.black87,
                  child: InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        result.filePath,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf_rounded, size: 54, color: Colors.white70),
                              SizedBox(height: 12),
                              Text('Document PDF / Archive d’analyse', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
