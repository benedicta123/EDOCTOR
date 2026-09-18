import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../auth/login_screen.dart';

/// GET /api/patients/{id}/dossier — autorisé si consultation en cours / terminée.
class PatientDossierScreen extends StatefulWidget {
  final int patientId;
  final String patientName;
  const PatientDossierScreen(
      {super.key, required this.patientId, required this.patientName});
  @override
  State<PatientDossierScreen> createState() => _PatientDossierScreenState();
}

class _PatientDossierScreenState extends State<PatientDossierScreen> {
  Map<String, dynamic>? _dossier;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getPatientDossier(widget.patientId);
      if (mounted) {
        setState(() {
          _dossier = d;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showMsg(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = (_dossier?['patient'] as Map<String, dynamic>?) ?? {};
    final consultations = (_dossier?['consultations'] as List?) ?? [];
    final prescriptions = (_dossier?['prescriptions'] as List?) ?? [];
    final name =
        patient['name'] as String? ?? (widget.patientName.isNotEmpty ? widget.patientName : 'Patient #${widget.patientId}');

    return ResponsiveShell(
      title: widget.patientName.isEmpty
          ? 'Dossier patient #${widget.patientId}'
          : 'Dossier · ${widget.patientName}',
      subtitle: 'Antécédents, consultations et ordonnances du patient',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.doctor(
        userName: 'Docteur',
        onLogout: _logout,
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carte identité patient
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Né(e) le ${patient['date_of_birth'] ?? 'date non renseignée'}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 18, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Antécédents médicaux',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.secondary),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              patient['medical_history_summary']
                                      ?.toString() ??
                                  'Aucun antécédent renseigné.',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13.5,
                                  height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeader(title: 'Consultations (${consultations.length})'),
                const SizedBox(height: 10),
                if (consultations.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.event_busy_rounded,
                    title: 'Aucune consultation',
                    message:
                        'Ce patient n’a encore aucune consultation enregistrée avec vous.',
                  )
                else
                  ...consultations.map((e) {
                    final m = e as Map<String, dynamic>;
                    final date = formatDateTime(
                      (m['started_at'] ?? m['scheduled_at'] ?? m['created_at'])
                          ?.toString(),
                    );
                    final diagnosis =
                        (m['diagnosis']?.toString() ?? '').trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Consultation #${m['id']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5),
                                ),
                              ),
                              StatusChip(
                                  status: m['status']?.toString() ?? ''),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.event_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                date,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (diagnosis.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                    Icons.notes_rounded,
                                    size: 14,
                                    color: AppColors.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    diagnosis,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textPrimary,
                                        height: 1.45),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                SectionHeader(title: 'Ordonnances (${prescriptions.length})'),
                const SizedBox(height: 10),
                if (prescriptions.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune ordonnance',
                    message:
                        'Aucune ordonnance n’a été rédigée pour ce patient.',
                  )
                else
                  ...prescriptions.map((e) {
                    final m = e as Map<String, dynamic>;
                    final items = (m['items'] as List?) ?? [];
                    final consultationId = (m['consultation_id'] as num?)
                        ?.toInt();
                    String medicationLabel(Map<String, dynamic> it) {
                      final med = it['medication']
                          as Map<String, dynamic>?;
                      final name = (med?['name'] ??
                              med?['commercial_name'])
                          ?.toString();
                      final dosage =
                          it['dosage_instructions']?.toString() ?? '';
                      final qty =
                          (it['quantity'] as num?)?.toInt() ?? 1;
                      final head = (name == null || name.isEmpty)
                          ? 'Médicament'
                          : name;
                      return '$head — $dosage (qté $qty)';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          title: Text('Ordonnance #${m['id']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5)),
                          subtitle: consultationId == null
                              ? null
                              : Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.link_rounded,
                                          size: 13,
                                          color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Liée à la consultation #$consultationId',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                          trailing: StatusChip(
                              status: m['status']?.toString() ?? ''),
                          children: items.isEmpty
                              ? const [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('Aucun médicament détaillé.',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary)),
                                  )
                                ]
                              : items
                                  .map((it) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.medication_rounded,
                                                  size: 16,
                                                  color: AppColors.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  medicationLabel(it as Map<
                                                      String,
                                                      dynamic>),
                                                  style: const TextStyle(
                                                      fontSize: 12.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ))
                                  .toList(),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}
