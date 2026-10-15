import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/badge_chip.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/official_document_viewer_modal.dart';
import '../../data/models/pharmacy_model.dart';

class PharmacyDetailModal extends StatelessWidget {
  final PharmacyModel pharmacy;
  final Function(PharmacyModel) onVerify;
  final Function(PharmacyModel, String) onReject;
  final Function(PharmacyModel, String) onSuspend;
  final Function(PharmacyModel) onReactivate;

  const PharmacyDetailModal({
    super.key,
    required this.pharmacy,
    required this.onVerify,
    required this.onReject,
    required this.onSuspend,
    required this.onReactivate,
  });

  static Future<void> show({
    required BuildContext context,
    required PharmacyModel pharmacy,
    required Function(PharmacyModel) onVerify,
    required Function(PharmacyModel, String) onReject,
    required Function(PharmacyModel, String) onSuspend,
    required Function(PharmacyModel) onReactivate,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 870),
          child: PharmacyDetailModal(
            pharmacy: pharmacy,
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
                      color: const Color(0xFF0D9488),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pharmacy.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          BadgeChip.status(pharmacy.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dossier de conformité officine partenaire (KYB/KYP) • Réf : ${pharmacy.referenceId ?? "—"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                if (pharmacy.rejectedReason != null && pharmacy.rejectedReason!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pharmacy.isSuspended ? AppColors.suspendedBg : AppColors.rejectedBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pharmacy.isSuspended ? AppColors.suspendedBorder : AppColors.rejectedBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          pharmacy.isSuspended ? Icons.block_rounded : Icons.warning_rounded,
                          color: pharmacy.isSuspended ? AppColors.suspended : AppColors.rejected,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pharmacy.isSuspended ? 'Motif de suspension réglementaire :' : 'Motif de rejet de l\'agrément :',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: pharmacy.isSuspended ? AppColors.suspended : AppColors.rejected,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pharmacy.rejectedReason!,
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

                // Grille 2 colonnes : Officine & Pharmacien Titulaire
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        title: 'Identification Officine',
                        icon: Icons.store_rounded,
                        rows: [
                          _buildDetailRow('Nom Pharmacie', pharmacy.name),
                          _buildDetailRow('Référence Dossier', pharmacy.referenceId ?? 'N/A', isBold: true),
                          _buildDetailRow('Adresse', pharmacy.address ?? 'Non renseignée'),
                          _buildDetailRow('Téléphone', pharmacy.phone ?? 'Non renseigné'),
                          _buildDetailRow('Email Officiel', pharmacy.officialEmail ?? 'Non renseigné'),
                          _buildDetailRow('N° Contribuable (NIF)', pharmacy.taxNumber ?? 'Non communiqué'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        title: 'Pharmacien Titulaire & Licences',
                        icon: Icons.badge_rounded,
                        rows: [
                          _buildDetailRow('Docteur Titulaire', pharmacy.owner?.name ?? 'Non assigné', isBold: true),
                          _buildDetailRow('N° Inscription Ordre (ONP)', pharmacy.orderNumber ?? 'NON COMMUNIQUÉ', isBold: true),
                          _buildDetailRow('N° Licence d\'Officine', pharmacy.licenseNumber ?? 'NON COMMUNIQUÉ', isBold: true),
                          _buildDetailRow('Téléphone Mobile', pharmacy.owner?.phone ?? '—'),
                          _buildDetailRow('Date Dépôt Dossier', Formatters.formatDateTime(pharmacy.createdAt)),
                          _buildDetailRow('Statut Agrément', pharmacy.statusLabel),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section Contrôle des Pièces Justificatives KYP
                const Text(
                  'Pièces Justificatives Réglementaires (Audit KYP)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    _buildDocumentItem(
                      title: 'Licence d\'Exploitation d\'Officine de Pharmacie',
                      subtitle: 'Document justificatif • Réf : ${pharmacy.licenseNumber ?? "LIC-OFF-2026"}',
                      isUploaded: true,
                      onOpen: () {
                        OfficialDocumentViewerModal.show(
                          context: context,
                          type: DocumentType.pharmacyLicense,
                          entityName: pharmacy.name,
                          licenseNumber: pharmacy.licenseNumber,
                          orderNumber: pharmacy.orderNumber,
                          taxNumber: pharmacy.taxNumber,
                          address: pharmacy.address,
                          contactName: pharmacy.owner?.name,
                          phone: pharmacy.phone ?? pharmacy.owner?.phone,
                          officialEmail: pharmacy.officialEmail ?? pharmacy.owner?.email,
                          dateIssued: pharmacy.createdAt,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildDocumentItem(
                      title: 'Diplôme d\'État de Docteur en Pharmacie du Titulaire',
                      subtitle: 'Qualification universitaire et inscription de l\'impétrant titulaire',
                      isUploaded: true,
                      onOpen: () {
                        OfficialDocumentViewerModal.show(
                          context: context,
                          type: DocumentType.pharmacistDiploma,
                          entityName: pharmacy.name,
                          orderNumber: pharmacy.orderNumber,
                          contactName: pharmacy.owner?.name,
                          address: pharmacy.address,
                          dateIssued: pharmacy.createdAt,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildDocumentItem(
                      title: 'Attestation d\'Inscription au Tableau de l\'Ordre National des Pharmaciens',
                      subtitle: 'Attestation ordinale en cours de validité • Réf : ${pharmacy.orderNumber ?? "ONP-2026"}',
                      isUploaded: true,
                      onOpen: () {
                        OfficialDocumentViewerModal.show(
                          context: context,
                          type: DocumentType.pharmacyOrderCertificate,
                          entityName: pharmacy.name,
                          orderNumber: pharmacy.orderNumber,
                          licenseNumber: pharmacy.licenseNumber,
                          contactName: pharmacy.owner?.name,
                          address: pharmacy.address,
                          dateIssued: pharmacy.createdAt,
                        );
                      },
                    ),
                  ],
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
                  if (pharmacy.isSuspended) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Lever la suspension'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.verified, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        onReactivate(pharmacy);
                      },
                    ),
                  ],

                  // Si vérifié -> Proposer suspension
                  if (pharmacy.isVerified) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: const Text('Suspendre le partenariat'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.suspended, foregroundColor: Colors.white),
                      onPressed: () async {
                        final reason = await ConfirmActionDialog.show(
                          context: context,
                          title: 'Suspendre le partenariat officine',
                          message: 'La suspension retirera temporairement l\'officine de la dispensation des ordonnances et de l\'application eDoctor.',
                          confirmLabel: 'Confirmer la suspension',
                          confirmColor: AppColors.suspended,
                          icon: Icons.block_rounded,
                          requireReason: true,
                          reasonHint: 'Précisez le motif de la suspension du partenariat...',
                          quickReasons: [
                            'Rupture de continuité de service officinal',
                            'Dispensation de produits non conformes',
                            'Radiation ou défaut de cotisation ordinale',
                            'Litige non résolu sur la dispensation',
                          ],
                        );
                        if (reason != null && context.mounted) {
                          Navigator.pop(context);
                          onSuspend(pharmacy, reason);
                        }
                      },
                    ),
                  ],

                  // Si en attente ou rejeté -> Boutons Valider / Rejeter
                  if (pharmacy.isPending || pharmacy.isRejected) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Rejeter la demande'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.rejected, side: const BorderSide(color: AppColors.rejected)),
                      onPressed: () async {
                        final reason = await ConfirmActionDialog.show(
                          context: context,
                          title: 'Rejeter la demande d\'accréditation',
                          message: 'L\'officine recevra une notification avec le motif ci-dessous afin de corriger ses pièces.',
                          confirmLabel: 'Rejeter la demande',
                          confirmColor: AppColors.rejected,
                          icon: Icons.cancel_outlined,
                          requireReason: true,
                          reasonHint: 'Indiquez les pièces manquantes ou non conformes...',
                          quickReasons: [
                            'Diplôme de docteur non conforme ou non joint',
                            'Numéro d\'inscription à l\'Ordre non vérifiable',
                            'Licence d\'officine non conforme ou expirée',
                          ],
                        );
                        if (reason != null && context.mounted) {
                          Navigator.pop(context);
                          onReject(pharmacy, reason);
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
                          title: 'Valider le partenariat officine',
                          message: 'Confirmez-vous que la pharmacie ${pharmacy.name} et son titulaire ont validé le contrôle de conformité eDoctor ?',
                          confirmLabel: 'Valider le partenariat',
                          confirmColor: AppColors.verified,
                          icon: Icons.verified_rounded,
                        );
                        if (confirm != null && context.mounted) {
                          Navigator.pop(context);
                          onVerify(pharmacy);
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

  Widget _buildDocumentItem({
    required String title,
    required String subtitle,
    required bool isUploaded,
    required VoidCallback onOpen,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.menu_book_rounded, size: 14),
            label: const Text('Ouvrir & Lire', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: onOpen,
          ),
        ],
      ),
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
              Icon(icon, size: 18, color: const Color(0xFF0D9488)),
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
                color: isBold ? const Color(0xFF0D9488) : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
