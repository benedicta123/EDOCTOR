import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../data/models/consultation_model.dart';
import '../consultation_detail_screen.dart';
import '../video_consultation_screen.dart';

/// Carte de consultation unifiée pour le Praticien :
/// Affichée à la fois dans "Mes consultations" et dans "Activités récentes" du Dashboard.
class ConsultationCard extends StatelessWidget {
  final ConsultationModel consultation;
  final VoidCallback? onRefresh;
  final int? actingId;
  final Future<void> Function(ConsultationModel)? onAccept;
  final Future<void> Function(ConsultationModel)? onDecline;

  const ConsultationCard({
    super.key,
    required this.consultation,
    this.onRefresh,
    this.actingId,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = consultation.status == 'en_attente';
    final isLive = consultation.status == 'en_cours';
    final acting = actingId == consultation.id;
    final patientName = consultation.patientName.isNotEmpty
        ? consultation.patientName
        : 'Patient #${consultation.patientId}';
    final diagnosis = (consultation.diagnosis != null &&
            consultation.diagnosis!.trim().isNotEmpty)
        ? consultation.diagnosis!.trim()
        : 'Non renseigné';
    final rxSummary = consultation.medicationsSummary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive
              ? AppColors.primary
              : isPending
                  ? AppColors.warning.withValues(alpha: 0.6)
                  : AppColors.border,
          width: isLive ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isLive ? AppColors.primary : Colors.black)
                .withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => ConsultationDetailScreen(
                  consultation: consultation,
                ),
              ),
            )
            .then((_) => onRefresh?.call()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── En-tête : Avatar + Nom + Date & Heure + Statut ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: isPending
                            ? AppColors.warningLight
                            : isLive
                                ? AppColors.primaryContainer
                                : AppColors.secondaryContainer,
                        child: Text(
                          patientName.isNotEmpty
                              ? patientName[0].toUpperCase()
                              : 'P',
                          style: TextStyle(
                            color: isPending
                                ? AppColors.warning
                                : isLive
                                    ? AppColors.primary
                                    : AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isPending)
                        const Positioned(
                          right: -2,
                          top: -2,
                          child: PulsingDot(),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer
                                    .withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.2),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                consultation.displayCode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              consultation.formattedDateTime,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPending || isLive) ...[
                        IconButton(
                          tooltip: isPending
                              ? 'Lancer en vidéo'
                              : 'Rejoindre la vidéo',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppColors.secondary.withValues(alpha: 0.08),
                          ),
                          color: AppColors.secondary,
                          icon: const Icon(Icons.videocam_rounded, size: 20),
                          onPressed: () => VideoConsultation.launch(
                            context,
                            consultation,
                            startIfNeeded: isPending,
                          ).then((_) => onRefresh?.call()),
                        ),
                        const SizedBox(width: 6),
                      ],
                      StatusChip(status: consultation.status),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 12),

              // ─── Détails : Durée, Diagnostic, Médicaments ───
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Durée de la consultation
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Durée : ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          consultation.durationText,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isLive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Diagnostic posé
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.medical_information_outlined,
                          size: 15,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Diagnostic : ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            diagnosis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: diagnosis == 'Non renseigné'
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                              fontStyle: diagnosis == 'Non renseigné'
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Médicaments prescrits
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.medication_outlined,
                          size: 15,
                          color: Color(0xFF0D9488),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Prescription : ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rxSummary,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: rxSummary.contains('Aucun')
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                              color: rxSummary.contains('Aucun')
                                  ? AppColors.textMuted
                                  : const Color(0xFF0F766E),
                              fontStyle: rxSummary.contains('Aucun')
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── Actions Accepter / Refuser si en attente ───
              if (isPending && onAccept != null && onDecline != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed:
                              acting ? null : () => onAccept!(consultation),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: acting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(acting ? 'Acceptation…' : 'Accepter'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed:
                            acting ? null : () => onDecline!(consultation),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Refuser'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.25).animate(_ctrl),
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: AppColors.warning,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

class DeclineDialog extends StatefulWidget {
  final String patientName;

  const DeclineDialog({super.key, required this.patientName});

  @override
  State<DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<DeclineDialog> {
  String _selectedReason = 'Actuellement indisponible / en consultation';

  final List<String> _reasons = [
    'Actuellement indisponible / en consultation',
    'Urgence au bloc ou en clinique',
    'Hors créneau de garde / consultation terminée',
    'Patient orienté vers un service d\'urgence',
    'Problème technique temporaire',
  ];

  @override
  Widget build(BuildContext context) {
    final name = widget.patientName.isEmpty ? 'ce patient' : widget.patientName;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.call_end_rounded, color: AppColors.error, size: 22),
          SizedBox(width: 10),
          Text(
            'Refuser la consultation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Indiquez le motif de refus pour $name. Le patient recevra une notification instantanée.',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.background,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedReason,
                items: _reasons.map((r) {
                  return DropdownMenuItem<String>(
                    value: r,
                    child: Text(
                      r,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(_selectedReason),
          child: const Text('Confirmer le refus'),
        ),
      ],
    );
  }
}
