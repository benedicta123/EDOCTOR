import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/consultation_model.dart';
import '../../../data/models/lab_request_model.dart';

/// Modal et vue dédiée aux Prescriptions de bilans de laboratoire & examens complémentaires.
class LabRequestsSection extends StatefulWidget {
  final ConsultationModel consultation;
  final List<LabRequestModel> labRequests;
  final VoidCallback onRefresh;
  final bool compact;

  const LabRequestsSection({
    super.key,
    required this.consultation,
    required this.labRequests,
    required this.onRefresh,
    this.compact = false,
  });

  @override
  State<LabRequestsSection> createState() => _LabRequestsSectionState();
}

class _LabRequestsSectionState extends State<LabRequestsSection> {
  void _openPrescriptionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PrescribeLabModal(
        consultation: widget.consultation,
        onSuccess: widget.onRefresh,
      ),
    );
  }

  void _openReviewModal(LabRequestModel lab) {
    showDialog(
      context: context,
      builder: (ctx) => _ReviewLabDialog(
        labRequest: lab,
        onSuccess: widget.onRefresh,
      ),
    );
  }

  void _openResultPreview(LabRequestResultModel result) {
    showDialog(
      context: context,
      builder: (ctx) => _ResultViewerDialog(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labs = widget.labRequests;
    final canPrescribe = !widget.consultation.isClosed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.biotech_rounded, size: 22, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Examens & Bilans de laboratoire',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (labs.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${labs.length}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (canPrescribe)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _openPrescriptionModal,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Prescrire un examen',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (labs.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.biotech_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aucun examen biologique ou imagerie prescrit',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        canPrescribe
                            ? 'Prescrivez des analyses (NFS, Paludisme, Glycémie, Radio…) pour orienter le diagnostic.'
                            : 'Aucune analyse complémentaire n’a été requise pour cette consultation.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...labs.map((lab) => _buildLabCard(lab)),
      ],
    );
  }

  Widget _buildLabCard(LabRequestModel lab) {
    Color statusColor;
    Color statusBg;
    switch (lab.status) {
      case 'resultats_recus':
        statusColor = const Color(0xFF0284C7);
        statusBg = const Color(0xFFE0F2FE);
        break;
      case 'analyse_terminee':
        statusColor = AppColors.success;
        statusBg = AppColors.successLight;
        break;
      case 'en_attente_resultats':
      case 'prescrit':
      default:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lab.status == 'resultats_recus'
              ? const Color(0xFF0284C7).withValues(alpha: 0.5)
              : AppColors.border,
          width: lab.status == 'resultats_recus' ? 1.5 : 1.0,
        ),
        boxShadow: lab.status == 'resultats_recus'
            ? [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                    fontSize: 12.5,
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.error),
                      SizedBox(width: 4),
                      Text(
                        'URGENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              if (lab.fastingRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'À JEUN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lab.statusDisplayLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Liste des examens demandés
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: lab.items.map((it) {
              final isImaging = it.category == 'imagerie';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isImaging
                      ? const Color(0xFFF3E8FF)
                      : AppColors.surfaceDim.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isImaging
                        ? const Color(0xFFD8B4FE)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isImaging ? Icons.image_rounded : Icons.science_rounded,
                      size: 15,
                      color: isImaging
                          ? const Color(0xFF7E22CE)
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      it.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isImaging
                            ? const Color(0xFF6B21A8)
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (it.instructions != null && it.instructions!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${it.instructions})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          if (lab.clinicalNotes != null && lab.clinicalNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Indication clinique : ${lab.clinicalNotes}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          // Résultats téléversés
          if (lab.hasResults) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.attach_file_rounded, size: 17, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Text(
                  'Résultats transmis (${lab.results.length} document${lab.results.length > 1 ? 's' : ''})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: lab.results.map((res) {
                return InkWell(
                  onTap: () => _openResultPreview(res),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          res.isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                          size: 20,
                          color: const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              res.fileName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0369A1),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Par ${res.uploaderName} · ${res.formattedDate}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF0284C7)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // Conclusions du médecin si déjà analysé
          if (lab.doctorReviewNotes != null && lab.doctorReviewNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_rounded, size: 17, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Conclusions médicales du praticien :',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lab.doctorReviewNotes!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Bouton d'action pour le médecin s'il y a des résultats à valider
          if (lab.hasResults && lab.status != 'analyse_terminee') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openReviewModal(lab),
                icon: const Icon(Icons.rate_review_rounded, size: 16),
                label: const Text(
                  'Valider l’analyse du bilan',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal de prescription d'examens complémentaires
class _PrescribeLabModal extends StatefulWidget {
  final ConsultationModel consultation;
  final VoidCallback onSuccess;

  const _PrescribeLabModal({
    required this.consultation,
    required this.onSuccess,
  });

  @override
  State<_PrescribeLabModal> createState() => _PrescribeLabModalState();
}

class _PrescribeLabModalState extends State<_PrescribeLabModal> {
  final _clinicalNotesCtrl = TextEditingController();
  final _customTestCtrl = TextEditingController();
  final _customInstructionCtrl = TextEditingController();
  String _selectedCategory = 'biologie';
  bool _urgent = false;
  bool _fasting = false;
  bool _submitting = false;

  final List<Map<String, dynamic>> _selectedItems = [];

  // Catalogue prédéfini d'analyses courantes
  static const List<Map<String, String>> _frequentTests = [
    {'name': 'Goutte Épaisse & Frottis (GE/FS) - Paludisme', 'category': 'parasitologie'},
    {'name': 'Test de Diagnostic Rapide (TDR Palu)', 'category': 'parasitologie'},
    {'name': 'Numération Formule Sanguine (NFS / Hémogramme)', 'category': 'biologie'},
    {'name': 'Test de Widal (Fièvre typhoïde)', 'category': 'bacteriologie'},
    {'name': 'Glycémie à jeun', 'category': 'biologie'},
    {'name': 'Créatinine & Urée sérique (Bilan rénal)', 'category': 'biologie'},
    {'name': 'Transaminases ASAT / ALAT (Bilan hépatique)', 'category': 'biologie'},
    {'name': 'Bilan lipidique (Cholestérol total, HDL, LDL, TG)', 'category': 'biologie'},
    {'name': 'CRP (Protéine C-Réactive)', 'category': 'biologie'},
    {'name': 'ECBU (Examen des Urines)', 'category': 'bacteriologie'},
    {'name': 'Radiographie pulmonaire (Face)', 'category': 'imagerie'},
    {'name': 'Échographie abdomino-pelvienne', 'category': 'imagerie'},
  ];

  @override
  void dispose() {
    _clinicalNotesCtrl.dispose();
    _customTestCtrl.dispose();
    _customInstructionCtrl.dispose();
    super.dispose();
  }

  void _togglePresetTest(Map<String, String> test) {
    setState(() {
      final existingIndex = _selectedItems.indexWhere((it) => it['name'] == test['name']);
      if (existingIndex >= 0) {
        _selectedItems.removeAt(existingIndex);
      } else {
        _selectedItems.add({
          'name': test['name']!,
          'category': test['category']!,
          'instructions': '',
        });
      }
    });
  }

  void _addCustomTest() {
    final name = _customTestCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _selectedItems.add({
        'name': name,
        'category': _selectedCategory,
        'instructions': _customInstructionCtrl.text.trim(),
      });
      _customTestCtrl.clear();
      _customInstructionCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (_selectedItems.isEmpty) {
      showMsg(context, 'Sélectionnez ou saisissez au moins un examen.', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.createLabRequest(
        consultationId: widget.consultation.id,
        items: _selectedItems,
        clinicalNotes: _clinicalNotesCtrl.text.trim(),
        urgencyLevel: _urgent ? 'urgent' : 'normal',
        fastingRequired: _fasting,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      showMsg(context, 'Ordonnance d’examens prescrite avec succès !');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showMsg(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Poignée supérieure
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.biotech_rounded, color: AppColors.primary, size: 26),
                const SizedBox(width: 10),
                const Text(
                  'Prescrire des examens complémentaires',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
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
                  // Sélecteur rapide des analyses fréquentes
                  const Text(
                    'Analyses et examens fréquents (cliquez pour ajouter) :',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _frequentTests.map((test) {
                      final isSelected = _selectedItems.any((it) => it['name'] == test['name']);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(test['name']!),
                        selectedColor: AppColors.primary.withValues(alpha: 0.18),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                        onSelected: (_) => _togglePresetTest(test),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Formulaire ajout manuel personnalisé
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDim.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ou ajouter un examen spécifique :',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _customTestCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Nom de l’examen (ex: Échographie Doppler...)',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _selectedCategory,
                              items: const [
                                DropdownMenuItem(value: 'biologie', child: Text('Biologie')),
                                DropdownMenuItem(value: 'imagerie', child: Text('Imagerie')),
                                DropdownMenuItem(value: 'parasitologie', child: Text('Parasitologie')),
                                DropdownMenuItem(value: 'bacteriologie', child: Text('Bactériologie')),
                                DropdownMenuItem(value: 'autre', child: Text('Autre')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customInstructionCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Consigne facultative (ex: Tube EDTA, 3e jour du cycle...)',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _addCustomTest,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Ajouter'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Examens actuellement retenus
                  if (_selectedItems.isNotEmpty) ...[
                    Text(
                      'Examens retenus pour cette ordonnance (${_selectedItems.length}) :',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 17, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item['name']} (${item['category']})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                              onPressed: () => setState(() => _selectedItems.removeAt(idx)),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                  ],
                  // Options cliniques
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Urgence médicale', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Traitement prioritaire au laboratoire', style: TextStyle(fontSize: 11.5)),
                          value: _urgent,
                          activeThumbColor: AppColors.error,
                          onChanged: (v) => setState(() => _urgent = v),
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('À jeun strict', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Prélèvement matinal avant repas', style: TextStyle(fontSize: 11.5)),
                          value: _fasting,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) => setState(() => _fasting = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Indication clinique
                  const Text(
                    'Renseignements cliniques / Hypothèses diagnostiques :',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _clinicalNotesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Fièvre persistante depuis 72h, frissons, asthénie. Recherche paludisme ou typhoïde.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Émettre l’ordonnance (${_selectedItems.length} examen${_selectedItems.length > 1 ? 's' : ''})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
}

/// Dialogue pour valider l'analyse médicale des résultats reçus
class _ReviewLabDialog extends StatefulWidget {
  final LabRequestModel labRequest;
  final VoidCallback onSuccess;

  const _ReviewLabDialog({
    required this.labRequest,
    required this.onSuccess,
  });

  @override
  State<_ReviewLabDialog> createState() => _ReviewLabDialogState();
}

class _ReviewLabDialogState extends State<_ReviewLabDialog> {
  final _reviewNotesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reviewNotesCtrl.text = widget.labRequest.doctorReviewNotes ?? '';
  }

  @override
  void dispose() {
    _reviewNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ApiService.reviewLabRequest(
        widget.labRequest.id,
        doctorReviewNotes: _reviewNotesCtrl.text.trim(),
        status: 'analyse_terminee',
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      showMsg(context, 'Bilan analysé et validé.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showMsg(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Validation d’analyse (${widget.labRequest.referenceCode})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Rédigez votre interprétation médicale des résultats transmis. Ces conclusions seront notifiées au patient et archivées dans son dossier.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reviewNotesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ex: GE positive à Plasmodium falciparum (densité 15 000/µL). NFS montre anémie modérée. Prescription ACT indiquée.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Valider & Clôturer l’analyse'),
        ),
      ],
    );
  }
}

/// Visualiseur de documents & photographies d'analyses avec zoom interactif
class _ResultViewerDialog extends StatelessWidget {
  final LabRequestResultModel result;

  const _ResultViewerDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        decoration: BoxDecoration(
          color: const Color(0xFF132A45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Entête
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Transmis par ${result.uploaderName} · ${result.formattedDate}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            // Vue de l'image avec zoom interactif
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Container(
                  color: Colors.black87,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.network(
                        result.filePath,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54),
                                const SizedBox(height: 12),
                                const Text(
                                  'Aperçu non disponible directement',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  result.filePath,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (result.patientNotes != null && result.patientNotes!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black54,
                child: Text(
                  'Note du patient : ${result.patientNotes}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
