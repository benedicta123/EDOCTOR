import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/badge_chip.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/official_document_viewer_modal.dart';
import '../../data/models/hospital_model.dart';

class HospitalDetailModal extends StatelessWidget {
  final HospitalModel hospital;
  final Function(HospitalModel) onVerify;
  final Function(HospitalModel, String) onReject;
  final Function(HospitalModel, String) onSuspend;
  final Function(HospitalModel) onReactivate;

  const HospitalDetailModal({
    super.key,
    required this.hospital,
    required this.onVerify,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
  });

  static Future<void> show({
    required BuildContext context,
    required HospitalModel hospital,
    required Function(HospitalModel) onVerify,
    required Function(HospitalModel, String) onReject,
    required Function(HospitalModel, String) onSuspend,
    required Function(HospitalModel) onReactivate,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 850),
          child: HospitalDetailModal(
            hospital: hospital,
            onVerify: onVerify,
            onReject: onReject,
            onSuspend: onSuspend,
            onReactivate: onReactivate,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Modal Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.sidebarBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hospital.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          BadgeChip.status(hospital.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Dossier d\'accréditation & conformité partenaire eDoctor',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Modal Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alerte si rejeté ou suspendu
                if (hospital.rejectedReason != null && hospital.rejectedReason!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hospital.isSuspended ? AppColors.suspendedBg : AppColors.rejectedBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hospital.isSuspended ? AppColors.suspendedBorder : AppColors.rejectedBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          hospital.isSuspended ? Icons.block_rounded : Icons.warning_rounded,
                          color: hospital.isSuspended ? AppColors.suspended : AppColors.rejected,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hospital.isSuspended ? 'Motif de suspension réglementaire :' : 'Motif de rejet du dossier :',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: hospital.isSuspended ? AppColors.suspended : AppColors.rejected,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hospital.rejectedReason!,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Grille 2 colonnes : Informations Générales & Identification Fiscale
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        title: 'Identification Établissement',
                        icon: Icons.business_rounded,
                        rows: [
                          _buildDetailRow('Nom Officiel', hospital.name),
                          _buildDetailRow('Adresse Physique', hospital.address ?? 'Non renseignée'),
                          _buildDetailRow('Téléphone Standard', hospital.phone ?? 'Non renseigné'),
                          _buildDetailRow('Email Institutionnel', hospital.officialEmail ?? 'Non renseigné'),
                          _buildDetailRow('Date Enregistrement', Formatters.formatDateTime(hospital.createdAt)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        title: 'Agrément Sanitaire & Fiscalité',
                        icon: Icons.verified_user_rounded,
                        rows: [
                          _buildDetailRow('N° Autorisation Sanitaire', hospital.licenseNumber ?? 'NON COMMUNIQUÉ', isBold: true),
                          _buildDetailRow('N° Compte Contribuable (NIF)', hospital.taxNumber ?? 'Non communiqué'),
                          _buildDetailRow('Statut Légal', hospital.statusLabel),
                          _buildDetailRow('Date d\'accréditation', Formatters.formatDate(hospital.verifiedAt)),
                          _buildDetailRow('Effectif Soignants Rattachés', '${hospital.doctorsCount} médecin(s) • ${hospital.staffCount} personnel'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section Pièces Justificatives (Audit de Conformité)
                const Text(
                  'Pièce Justificative Déposée (Audit Partenaire)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hospital.licenseDocumentPath != null
                                  ? hospital.licenseDocumentPath!.split('/').last
                                  : 'Autorisation d\'Ouverture & Agrément Sanitaire',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pièce transmise par l\'établissement • Réf : ${hospital.licenseNumber ?? "AGR-2026"} • Format PDF',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: const Text('Examiner la pièce'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () {
                          OfficialDocumentViewerModal.show(
                            context: context,
                            type: DocumentType.hospitalLicense,
                            entityName: hospital.name,
                            licenseNumber: hospital.licenseNumber,
                            taxNumber: hospital.taxNumber,
                            address: hospital.address,
                            officialEmail: hospital.officialEmail,
                            phone: hospital.phone,
                            dateIssued: hospital.createdAt,
                            onApprove: () => onVerify(hospital),
                            onReject: (reason) => onReject(hospital, reason),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Modal Action Footer (Boutons Réglementaires)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer l\'audit'),
              ),
              Row(
                children: [
                  // Si suspendu -> Proposer réactivation
                  if (hospital.isSuspended) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Lever la suspension'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.verified, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        onReactivate(hospital);
                      },
                    ),
                  ],

                  // Si vérifié -> Proposer suspension
                  if (hospital.isVerified) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: const Text('Suspendre le partenariat'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.suspended, foregroundColor: Colors.white),
                      onPressed: () async {
                        final reason = await ConfirmActionDialog.show(
                          context: context,
                          title: 'Suspendre le partenariat',
                          message: 'La suspension bloquera l\'accès praticiens et la visibilité de cet établissement sur eDoctor.',
                          confirmLabel: 'Confirmer la suspension',
                          confirmColor: AppColors.suspended,
                          icon: Icons.block_rounded,
                          requireReason: true,
                          reasonHint: 'Précisez le motif de la suspension du partenariat...',
                          quickReasons: [
                            'Autorisation d\'exercer contestée ou non renouvelée',
                            'Non-conformité des locaux et équipements',
                            'Signalements graves répétés de patients',
                            'Défaut de paiement des redevances SaaS',
                          ],
                        );
                        if (reason != null && context.mounted) {
                          Navigator.pop(context);
                          onSuspend(hospital, reason);
                        }
                      },
                    ),
                  ],

                  // Si en attente ou rejeté -> Boutons Valider / Rejeter
                  if (hospital.isPending || hospital.isRejected) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Rejeter la demande'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.rejected, side: const BorderSide(color: AppColors.rejected)),
                      onPressed: () async {
                        final reason = await ConfirmActionDialog.show(
                          context: context,
                          title: 'Rejeter la demande d\'accréditation',
                          message: 'L\'établissement recevra une notification avec les motifs ci-dessous afin de corriger ses pièces.',
                          confirmLabel: 'Rejeter la demande',
                          confirmColor: AppColors.rejected,
                          icon: Icons.cancel_outlined,
                          requireReason: true,
                          reasonHint: 'Indiquez les pièces manquantes ou non conformes...',
                          quickReasons: [
                            'N° d\'autorisation sanitaire invalide ou non vérifiable',
                            'Document illisible, tronqué ou expiré',
                            'Directeur médical non inscrit à l\'Ordre des Médecins',
                            'Incohérence entre NIF, RCCM et raison sociale',
                          ],
                        );
                        if (reason != null && context.mounted) {
                          Navigator.pop(context);
                          onReject(hospital, reason);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Valider le partenariat & Activer'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.verified, foregroundColor: Colors.white),
                      onPressed: () async {
                        final confirm = await ConfirmActionDialog.show(
                          context: context,
                          title: 'Valider l\'accréditation partenaire',
                          message: 'Confirmez-vous que les pièces justificatives de l\'établissement ${hospital.name} ont été auditées avec succès ?',
                          confirmLabel: 'Valider l\'accréditation',
                          confirmColor: AppColors.verified,
                          icon: Icons.verified_rounded,
                        );
                        if (confirm != null && context.mounted) {
                          Navigator.pop(context);
                          onVerify(hospital);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> rows}) {
    return Container(
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
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isBold ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
