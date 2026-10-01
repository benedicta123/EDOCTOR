import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prescription_pdf_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/prescription_model.dart';
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
                SectionHeader(
                  title: 'Dossier des consultations & ordonnances (${consultations.length})',
                ),
                const SizedBox(height: 10),
                if (consultations.isEmpty && prescriptions.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.event_busy_rounded,
                    title: 'Aucun historique médical',
                    message:
                        'Ce patient n’a encore aucune consultation ou ordonnance enregistrée.',
                  )
                else ...[
                  ...consultations.map((e) {
                    final m = e as Map<String, dynamic>;
                    final consultationId = (m['id'] as num?)?.toInt() ?? 0;
                    final refCode = m['reference_code']?.toString();
                    final displayCode = (refCode != null && refCode.trim().isNotEmpty) ? refCode : '#$consultationId';
                    final date = formatDateTime(
                      (m['started_at'] ?? m['scheduled_at'] ?? m['created_at'])
                          ?.toString(),
                    );
                    final consultationDiagnosis =
                        (m['diagnosis']?.toString() ?? '').trim();
                    final doctorName = m['doctor'] is Map<String, dynamic>
                        ? (m['doctor']['name']?.toString() ?? '')
                        : '';

                    // Recherche de l'ordonnance liée à cette consultation
                    final Map<int, Map<String, dynamic>> pById = {};
                    for (final p in prescriptions) {
                      if (p is Map<String, dynamic>) {
                        final cId = (p['consultation_id'] as num?)?.toInt();
                        if (cId != null) pById[cId] = p;
                      }
                    }

                    final pRaw = (m['prescription'] as Map<String, dynamic>?) ??
                        pById[consultationId];

                    PrescriptionModel? prescriptionModel;
                    if (pRaw != null) {
                      final pData = Map<String, dynamic>.from(pRaw);
                      if (!pData.containsKey('patient')) pData['patient'] = patient;
                      if (!pData.containsKey('consultation')) pData['consultation'] = m;
                      prescriptionModel = PrescriptionModel.fromJson(pData);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary, width: 1.4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─── 1. Informations concernant la consultation ───
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.medical_services_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Consultation $displayCode',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (doctorName.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Dr. $doctorName',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              StatusChip(status: m['status']?.toString() ?? ''),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.event_available_rounded,
                                  size: 15, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Date de consultation : $date',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (consultationDiagnosis.isNotEmpty &&
                              prescriptionModel == null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Diagnostic : $consultationDiagnosis',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],

                          // ─── Ligne légère de séparation ───
                          const SizedBox(height: 14),
                          const Divider(
                              height: 1, thickness: 1, color: AppColors.borderLight),
                          const SizedBox(height: 14),

                          // ─── 2. En bas de la ligne : Ordonnance de cette consultation ───
                          if (prescriptionModel != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    size: 16,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ordonnance #ORD-${prescriptionModel.id}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (prescriptionModel.homeCareRecommended)
                                        const Text(
                                          'Soins à domicile recommandés',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                StatusChip(status: prescriptionModel.status),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  tooltip: 'Exporter / Imprimer l\'ordonnance en PDF',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primaryContainer,
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.all(7),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.print_rounded, size: 18),
                                  onPressed: () async {
                                    try {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Exportation de l\'ordonnance en PDF...'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      await PrescriptionPdfService.printPrescription(prescriptionModel!);
                                    } catch (err) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erreur export : $err'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),

                            // Diagnostic posé avant émission de l'ordonnance
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.medical_information_outlined,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Diagnostic : ${prescriptionModel.diagnosis.isNotEmpty && prescriptionModel.diagnosis != "Non spécifié" ? prescriptionModel.diagnosis : (consultationDiagnosis.isNotEmpty ? consultationDiagnosis : "Non spécifié")}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Médicaments prescrits
                            const SizedBox(height: 10),
                            const Text(
                              'Médicaments prescrits :',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (prescriptionModel.items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Aucun médicament renseigné.',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textMuted),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: AppColors.borderLight),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Column(
                                  children: prescriptionModel.items.map((it) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Icon(
                                              Icons.medication_rounded,
                                              size: 15,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: AppColors.textPrimary,
                                                  height: 1.3,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: it.medicationName,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700),
                                                  ),
                                                  if (it.dosageInstructions
                                                      .isNotEmpty)
                                                    TextSpan(
                                                      text:
                                                          ' — ${it.dosageInstructions}',
                                                      style: const TextStyle(
                                                          color: AppColors
                                                              .textSecondary),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Qté : ${it.quantity}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ] else ...[
                            Row(
                              children: const [
                                Icon(Icons.receipt_long_outlined,
                                    size: 16, color: AppColors.textMuted),
                                SizedBox(width: 8),
                                Text(
                                  'Aucune ordonnance émise lors de cette consultation.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}
