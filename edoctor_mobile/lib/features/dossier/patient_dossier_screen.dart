import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/dossier_pdf_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/patient_bottom_nav.dart';
import '../../data/models/patient_dossier_model.dart';
import '../../data/models/user_model.dart';
import '../prescriptions/prescriptions_screen.dart';

class PatientDossierScreen extends StatefulWidget {
  final ValueChanged<int>? onNavSelected;

  const PatientDossierScreen({super.key, this.onNavSelected});

  @override
  State<PatientDossierScreen> createState() => _PatientDossierScreenState();
}

class _PatientDossierScreenState extends State<PatientDossierScreen> {
  final int _currentNavIndex = 2;

  bool _loading = true;
  String? _error;
  PatientDossier? _dossier;
  UserModel? _sessionUser;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadDossier();
  }

  Future<void> _loadDossier() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await StorageService.getUser();
      if (user == null) {
        throw Exception('Session expirée. Reconnectez-vous.');
      }
      _sessionUser = user;
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

  Future<void> _exportPdf() async {
    final dossier = _dossier;
    if (dossier == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await DossierPdfService.shareDossierPdf(dossier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dossier PDF généré depuis vos données réelles.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export impossible : ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _ageLabel(String? iso) {
    if (iso == null || iso.isEmpty) return 'Naissance non renseignée';
    try {
      final dob = DateTime.parse(iso);
      final now = DateTime.now();
      var age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      final d = dob.day.toString().padLeft(2, '0');
      final m = dob.month.toString().padLeft(2, '0');
      return 'Né(e) le $d/$m/${dob.year} ($age ans)';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 16,
        title: const Row(
          children: [
            Icon(Icons.folder_shared_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text(
              'Mon Dossier Médical',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined,
                    color: AppColors.primary),
            tooltip: 'Exporter en PDF',
            onPressed: (_loading || _dossier == null) ? null : _exportPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: PatientBottomNav(
        currentIndex: _currentNavIndex,
        onTabSelected: (index) {
          if (widget.onNavSelected != null) {
            widget.onNavSelected!(index);
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
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
            Text('Chargement du dossier depuis la base eDoctor...',
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
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDossier,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    final dossier = _dossier!;
    final patient = dossier.patient.name.isNotEmpty
        ? dossier.patient
        : (_sessionUser ?? dossier.patient);
    final ref =
        'Dossier #DOC-TG-${DateTime.now().year}-${patient.id.toString().padLeft(2, '0')}';
    final summary = (patient.medicalHistorySummary?.isNotEmpty == true)
        ? patient.medicalHistorySummary!
        : 'Non renseigné — déclaré à l\'inscription étape 2.';

    return RefreshIndicator(
      onRefresh: _loadDossier,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte En-tête Dossier (données réelles)
            Container(
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
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.badge_rounded,
                        color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          patient.name.isNotEmpty
                              ? patient.name
                              : 'Patient #${patient.id}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_ageLabel(patient.dateOfBirth)}'
                          '${(patient.address?.isNotEmpty == true) ? ' • ${patient.address}' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTIF',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Activité réelle suivie',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Consultations',
                    value: '${dossier.consultations.length}',
                    sub: 'tenues (en_cours/terminee)',
                    icon: Icons.videocam_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Ordonnances',
                    value: '${dossier.prescriptions.length}',
                    sub: 'validées en base',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Référent',
                    value: dossier.referringDoctor != null ? 'Suivi' : '—',
                    sub: dossier.referringDoctor ?? 'Aucun pour le moment',
                    icon: Icons.local_hospital_rounded,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Antécédents déclarés à l'inscription (texte exact du patient)
            _buildSectionCard(
              icon: Icons.medical_information_outlined,
              iconColor: AppColors.primary,
              title: 'Antécédents déclarés à l\u2019inscription',
              content: Text(
                summary,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary, height: 1.4),
              ),
            ),

            const SizedBox(height: 16),

            // Consultations réelles
            _buildSectionCard(
              icon: Icons.videocam_rounded,
              iconColor: AppColors.primary,
              title:
                  'Consultations tenues (${dossier.consultations.length})',
              content: dossier.consultations.isEmpty
                  ? const Text(
                      'Aucune consultation en_cours/terminee pour ce patient en base.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    )
                  : Column(
                      children: [
                        for (var i = 0;
                            i < dossier.consultations.length;
                            i++) ...[
                          _buildItemRow(
                            label:
                                '#${dossier.consultations[i].id} — ${dossier.consultations[i].doctorName}',
                            detail:
                                '${dossier.consultations[i].doctorSpecialty ?? 'Médecine'} • ${dossier.consultations[i].displayDate}',
                            badge: dossier.consultations[i].status
                                .toUpperCase(),
                            badgeColor: AppColors.primary,
                            badgeBg: AppColors.primaryContainer,
                          ),
                          if (i < dossier.consultations.length - 1)
                            const Divider(
                                height: 18, color: AppColors.borderLight),
                        ],
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // Ordonnances réelles
            _buildSectionCard(
              icon: Icons.receipt_long_rounded,
              iconColor: AppColors.primary,
              title:
                  'Ordonnances validées (${dossier.prescriptions.length})',
              content: dossier.prescriptions.isEmpty
                  ? const Text(
                      'Aucune ordonnance validée pour ce patient en base.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    )
                  : Column(
                      children: [
                        for (var i = 0;
                            i < dossier.prescriptions.length;
                            i++) ...[
                          _buildItemRow(
                            label:
                                'Ordonnance #${dossier.prescriptions[i].id} — ${dossier.prescriptions[i].doctorName}',
                            detail: dossier
                                    .prescriptions[i].items.isEmpty
                                ? 'Aucun médicament renseigné.'
                                : dossier.prescriptions[i].items
                                    .map((it) =>
                                        '• ${it.medicationName}${it.dosage?.isNotEmpty == true ? ' — ${it.dosage}' : ''}${it.quantity != null ? ' (x${it.quantity})' : ''}')
                                    .join('\n'),
                            badge: dossier.prescriptions[i].status
                                .toUpperCase(),
                            badgeColor: AppColors.success,
                            badgeBg: AppColors.successLight,
                          ),
                          if (i < dossier.prescriptions.length - 1)
                            const Divider(
                                height: 18, color: AppColors.borderLight),
                        ],
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // Médecin référent dérivé
            _buildSectionCard(
              icon: Icons.contact_emergency_outlined,
              iconColor: AppColors.primary,
              title: 'Médecin référent (dérivé)',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryContainer,
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dossier.referringDoctor ??
                                  'Aucun médecin pour le moment',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                            const Text(
                              'Dernier praticien ayant tenu une consultation',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 10),
                  Text(
                    (patient.phone?.isNotEmpty == true)
                        ? 'Contact patient : ${patient.phone}'
                        : 'Contact patient : non renseigné',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PrescriptionsScreen()),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded,
                    color: AppColors.primary),
                label: const Text(
                  'Voir toutes les ordonnances archivées',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String sub,
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
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(sub,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  Widget _buildItemRow({
    required String label,
    required String detail,
    required String badge,
    required Color badgeColor,
    required Color badgeBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}
