import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/ringtone/ringtone_player.dart';
import '../../../data/models/consultation_model.dart';
import '../video_consultation_screen.dart';

/// Modal d'alerte sonore et visuelle en temps réel pour appel entrant
class IncomingCallModal extends StatefulWidget {
  final ConsultationModel consultation;

  const IncomingCallModal({
    super.key,
    required this.consultation,
  });

  /// Statut statique pour éviter les doublons de modales
  static bool isShown = false;
  static int? activeConsultationId;
  static BuildContext? _activeContext;

  /// Ouvre le modal d'appel entrant de façon bloquante et démarre la sonnerie
  static Future<void> show(
    BuildContext context,
    ConsultationModel consultation,
  ) async {
    if (isShown && activeConsultationId == consultation.id) return;
    if (isShown) {
      // Déjà un appel affiché
      return;
    }

    isShown = true;
    activeConsultationId = consultation.id;
    IncomingCallAudio.start();

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Appel entrant',
        barrierColor: Colors.black.withValues(alpha: 0.65),
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (dialogCtx, anim1, anim2) {
          _activeContext = dialogCtx;
          return IncomingCallModal(consultation: consultation);
        },
        transitionBuilder: (ctx, anim1, anim2, child) {
          final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
          return ScaleTransition(
            scale: curved,
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          );
        },
      );
    } finally {
      IncomingCallAudio.stop();
      isShown = false;
      activeConsultationId = null;
      _activeContext = null;
    }
  }

  /// Ferme la modale actuelle si elle est ouverte (ex: patient a raccroché)
  static void dismiss({bool cancelledByPatient = false}) {
    if (!isShown) return;
    IncomingCallAudio.stop();
    final ctx = _activeContext;
    if (ctx != null && ctx.mounted) {
      Navigator.of(ctx).pop();
      if (cancelledByPatient) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Le patient a annulé la demande de consultation.'),
            backgroundColor: AppColors.secondary,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
    isShown = false;
    activeConsultationId = null;
    _activeContext = null;
  }

  @override
  State<IncomingCallModal> createState() => _IncomingCallModalState();
}

class _IncomingCallModalState extends State<IncomingCallModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  bool _isAccepting = false;
  bool _isDeclining = false;
  bool _showReasonPicker = false;
  String _selectedReason = 'Actuellement indisponible / en consultation';

  final List<String> _quickReasons = [
    'Actuellement indisponible / en consultation',
    'Urgence au bloc ou en clinique',
    'Hors créneau de garde / consultation terminée',
    'Patient orienté vers un service d\'urgence',
    'Problème technique temporaire',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  String _formatElapsed(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _handleAccept() async {
    setState(() => _isAccepting = true);
    IncomingCallAudio.stop();

    try {
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop(); // Ferme le modal

      // Lance la visioconsultation directement
      await VideoConsultation.launch(
        nav.context,
        widget.consultation,
        startIfNeeded: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _handleDecline() async {
    setState(() => _isDeclining = true);
    IncomingCallAudio.stop();

    try {
      await ApiService.consultationAction(
        widget.consultation.id,
        'decline',
        reason: _selectedReason,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Demande de consultation refusée. Le patient a été notifié immédiatement.',
          ),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeclining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientName = widget.consultation.patientName.isNotEmpty
        ? widget.consultation.patientName
        : 'Patient #${widget.consultation.patientId}';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── En-tête bandeau appel entrant ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  color: AppColors.secondary,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'APPEL MÉDICAL EN DIRECT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatElapsed(_elapsedSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  child: Column(
                    children: [
                      // ── Animation d'ondes pulsées autour de l'avatar ──
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final value = _pulseController.value;
                          return SizedBox(
                            width: 130,
                            height: 130,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Onde extérieure
                                Container(
                                  width: 80 + (50 * value),
                                  height: 80 + (50 * value),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                      alpha: (1.0 - value) * 0.35,
                                    ),
                                  ),
                                ),
                                // Onde intermédiaire
                                Container(
                                  width: 80 + (25 * value),
                                  height: 80 + (25 * value),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                      alpha: (1.0 - value) * 0.45,
                                    ),
                                  ),
                                ),
                                // Avatar central
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryContainer,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 44,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── Nom du patient & sous-titre ──
                      Text(
                        patientName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Demande une consultation vidéo immédiate',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Vue normale OU Vue choix du motif de refus ──
                      if (!_showReasonPicker) ...[
                        // Bouton Accepter (Large Vert)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: (_isAccepting || _isDeclining)
                                ? null
                                : _handleAccept,
                            icon: _isAccepting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.videocam_rounded, size: 22),
                            label: Text(
                              _isAccepting
                                  ? 'Connexion à la salle...'
                                  : 'Accepter la consultation',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bouton Refuser / Reporter (Rouge élégant)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: (_isAccepting || _isDeclining)
                                ? null
                                : () => setState(() => _showReasonPicker = true),
                            icon: const Icon(
                              Icons.call_end_rounded,
                              size: 20,
                              color: AppColors.error,
                            ),
                            label: const Text(
                              'Refuser / Reporter',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.error.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // ── Sélection du motif de refus ──
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, size: 20),
                                onPressed: () =>
                                    setState(() => _showReasonPicker = false),
                                splashRadius: 18,
                              ),
                              const Text(
                                'Motif du refus pour le patient',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

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
                              icon: const Icon(Icons.keyboard_arrow_down_rounded),
                              items: _quickReasons.map((reason) {
                                return DropdownMenuItem<String>(
                                  value: reason,
                                  child: Text(
                                    reason,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedReason = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bouton Confirmer le refus
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isDeclining ? null : _handleDecline,
                            icon: _isDeclining
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.call_end_rounded, size: 18),
                            label: Text(
                              _isDeclining
                                  ? 'Envoi de la notification...'
                                  : 'Confirmer le refus',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
