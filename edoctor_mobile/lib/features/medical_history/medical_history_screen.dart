import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/dossier_pdf_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/patient_dossier_model.dart';
import '../prescriptions/prescriptions_screen.dart';

class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  bool _loading = true;
  String? _error;
  PatientDossier? _dossier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await StorageService.getUser();
      if (user == null) throw Exception('Session expirée. Reconnectez-vous.');
      final dossier = await ApiService.getPatientDossier(user.id);
      if (!mounted) return;
      setState(() {
        _dossier = dossier;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _share() async {
    final dossier = _dossier;
    if (dossier == null) return;
    try {
      await DossierPdfService.shareDossierPdf(dossier);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export impossible : ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Historique Médical',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.primary),
            tooltip: 'Exporter l\'historique (PDF)',
            onPressed: (_loading || _dossier == null) ? null : _share,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Chargement de l\u2019historique réel...',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 44, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    final dossier = _dossier!;
    final patient = dossier.patient;
    final summary = (patient.medicalHistorySummary?.isNotEmpty == true)
        ? patient.medicalHistorySummary!
        : 'Non renseigné — déclaré à l\u2019inscription.';
    final medsCount =
        dossier.prescriptions.fold<int>(0, (s, p) => s + p.items.length);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientSummaryCard(summary),
            const SizedBox(height: 20),
            const Text(
              'Activité réelle en base',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Compteurs dérivés des consultations tenues et ordonnances validées. Aucune constante inventée.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(
              consultations: dossier.consultations.length,
              prescriptions: dossier.prescriptions.length,
              meds: medsCount,
            ),
            const SizedBox(height: 24),
            Text(
              'Chronologie des soins (${dossier.consultations.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Consultations numérotées dans l’ordre chronologique, chacune avec son ordonnance liée.',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _buildTimeline(context, dossier),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSummaryCard(String summary) {
    final patient = _dossier!.patient;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.health_and_safety_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name.isNotEmpty
                          ? patient.name
                          : 'Patient #${patient.id}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    const Text(
                      'Dossier médical patient — données réelles',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: Icons.note_alt_outlined,
            title: 'Antécédents déclarés (inscription)',
            value: summary,
            color: AppColors.primary,
            bgColor: AppColors.primaryContainer,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.bloodtype_rounded,
            title: 'Groupe sanguin',
            value: 'Non renseigné en base',
            color: AppColors.textSecondary,
            bgColor: AppColors.surfaceDim,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid({
    required int consultations,
    required int prescriptions,
    required int meds,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            title: 'Consultations',
            value: '$consultations',
            unit: 'tenues',
            status: 'en_cours/terminee',
            icon: Icons.videocam_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            title: 'Ordonnances',
            value: '$prescriptions',
            unit: 'validées',
            status: 'en base',
            icon: Icons.receipt_long_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            title: 'Médicaments',
            value: '$meds',
            unit: 'prescrits',
            status: 'cumulés',
            icon: Icons.medication_rounded,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required String unit,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(width: 3),
              Text(unit,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Chronologie des soins : consultations numérotées 1..n dans l'ordre
  /// chronologique (cercle vert), chacune avec son ordonnance liée,
  /// dates et médicaments. Les composants sont teintés vert eDoctor.
  Widget _buildTimeline(BuildContext context, PatientDossier dossier) {
    // Ordre chronologique (ancien → récent) pour la numérotation 1..n.
    final consultations = [...dossier.consultations]..sort((a, b) {
        final cmp = a.sortKey.compareTo(b.sortKey);
        return cmp != 0 ? cmp : a.id.compareTo(b.id);
      });

    // Ordonnances regroupées par consultation.
    final rxByConsultation = <int, List<DossierPrescription>>{};
    for (final p in dossier.prescriptions) {
      final key = p.consultationId;
      if (key == null) continue;
      rxByConsultation.putIfAbsent(key, () => []).add(p);
    }
    final knownIds = consultations.map((c) => c.id).toSet();
    final orphanRx = dossier.prescriptions
        .where((p) =>
            p.consultationId == null || !knownIds.contains(p.consultationId))
        .toList();

    if (consultations.isEmpty && orphanRx.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Aucun événement en base pour ce patient. Les consultations et ordonnances validées apparaîtront ici automatiquement.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...consultations.asMap().entries.map((entry) {
          final number = entry.key + 1; // 1..n dans l'ordre chronologique
          final c = entry.value;
          final linked = rxByConsultation[c.id] ?? const [];
          final isLast =
              entry.key == consultations.length - 1 && orphanRx.isEmpty;
          return _buildConsultationEntry(
            context,
            number: number,
            consultation: c,
            prescriptions: linked,
            isLast: isLast,
          );
        }),
        if (orphanRx.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text(
            'Ordonnances complémentaires',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ...orphanRx.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildPrescriptionBlock(context, p),
              )),
        ],
      ],
    );
  }

  /// Une entrée de chronologie : cercle vert numéroté + rail + carte.
  Widget _buildConsultationEntry(
    BuildContext context, {
    required int number,
    required DossierConsultation consultation,
    required List<DossierPrescription> prescriptions,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail : cercle numéroté vert + ligne verticale.
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Carte consultation.
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Consultation',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      _buildStatusPill(consultation.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.event_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          consultation.displayDateTime,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Dr ${consultation.doctorName}'
                          '${consultation.doctorSpecialty?.isNotEmpty == true ? ' • ${consultation.doctorSpecialty}' : ''}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (prescriptions.isEmpty)
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: AppColors.textMuted),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Aucune ordonnance prescrite lors de cette consultation.',
                            style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    )
                  else
                    ...prescriptions.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildPrescriptionBlock(context, p),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pastille de statut teintée vert.
  Widget _buildStatusPill(String status) {
    late final Color fg;
    late final Color bg;
    late final String label;
    switch (status) {
      case 'terminee':
        fg = AppColors.success;
        bg = AppColors.successLight;
        label = 'Terminée';
        break;
      case 'en_cours':
        fg = AppColors.primary;
        bg = AppColors.primaryContainer;
        label = 'En cours';
        break;
      case 'annulee':
        fg = AppColors.error;
        bg = AppColors.errorLight;
        label = 'Annulée';
        break;
      default:
        fg = AppColors.warning;
        bg = AppColors.warningLight;
        label = status.isEmpty ? '—' : status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  /// Bloc ordonnance liée : fond vert clair, médicaments, date, accès détail.
  Widget _buildPrescriptionBlock(
      BuildContext context, DossierPrescription p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Ordonnance',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryHover),
                ),
              ),
              Text(
                p.displayDate,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryHover),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (p.items.isEmpty)
            const Text(
              'Aucun médicament détaillé.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            )
          else
            ...p.items.map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.medication_rounded,
                          size: 15, color: AppColors.primary),
                      const SizedBox(width: 7),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                                height: 1.35),
                            children: [
                              TextSpan(
                                text: it.medicationName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              if (it.dosage?.isNotEmpty == true)
                                TextSpan(text: ' — ${it.dosage}'),
                              if (it.quantity != null)
                                TextSpan(
                                  text: '  •  Qté ${it.quantity}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PrescriptionsScreen()),
                );
              },
              icon: const Icon(Icons.receipt_long_rounded,
                  size: 14, color: AppColors.primary),
              label: const Text(
                'Voir l\'ordonnance',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
