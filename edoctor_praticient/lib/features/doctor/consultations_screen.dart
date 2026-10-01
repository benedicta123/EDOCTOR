import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/incoming_call_watcher.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import 'consultation_detail_screen.dart';
import 'video_consultation_screen.dart';

class DoctorConsultationsScreen extends StatefulWidget {
  const DoctorConsultationsScreen({super.key});

  @override
  State<DoctorConsultationsScreen> createState() =>
      _DoctorConsultationsScreenState();
}

class _DoctorConsultationsScreenState extends State<DoctorConsultationsScreen> {
  UserModel? _user;
  List<ConsultationModel> _consultations = [];
  bool _loading = true;
  String _filter = 'toutes';
  Timer? _autoRefresh;
  int? _actingId;

  static const _filters = <String, String>{
    'toutes': 'Toutes',
    'en_attente': 'En attente',
    'en_cours': 'En cours',
    'terminee': 'Terminées',
    'annulee': 'Annulées',
  };

  @override
  void initState() {
    super.initState();
    _load();
    IncomingCallWatcher.instance.start();
    _autoRefresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    try {
      final consultations = await ApiService.getConsultations();
      if (!mounted) return;
      setState(() => _consultations = consultations);
    } catch (_) {}
  }

  Future<void> _accept(ConsultationModel c) async {
    IncomingCallWatcher.instance.markHandled(c.id);
    setState(() => _actingId = c.id);
    try {
      await ApiService.consultationAction(c.id, 'start');
      if (!mounted) return;
      showMsg(context, 'Consultation ${c.displayCode} acceptée — en cours');
      await _silentRefresh();
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _decline(ConsultationModel c) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _DeclineDialog(patientName: c.patientName),
    );
    if (reason == null) return;

    IncomingCallWatcher.instance.markHandled(c.id);
    setState(() => _actingId = c.id);
    try {
      await ApiService.consultationAction(c.id, 'decline', reason: reason);
      if (!mounted) return;
      showMsg(context, 'Consultation ${c.displayCode} refusée. Le patient a été notifié.');
      await _silentRefresh();
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final consultations = await ApiService.getConsultations();
      if (mounted) {
        setState(() {
          _user = user;
          _consultations = consultations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  List<ConsultationModel> get _visible => _filter == 'toutes'
      ? _consultations
      : _consultations.where((item) => item.status == _filter).toList();

  int _countOf(String status) =>
      _consultations.where((c) => c.status == status).length;

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      title: 'Mes consultations',
      subtitle:
          '${_consultations.length} consultation(s) enregistrée(s) · ${_countOf('en_attente')} en attente',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.doctor(
        userName: _user?.name ?? 'Docteur',
        userSpecialty: _user?.specialty,
        currentSection: NavSection.consultations,
        consultationsPending: _countOf('en_attente'),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _filters.entries.map((entry) {
                    final count = entry.key == 'toutes'
                        ? _consultations.length
                        : _countOf(entry.key);
                    return ChoiceChip(
                      label: Text('${entry.value} ($count)'),
                      selected: _filter == entry.key,
                      onSelected: (_) =>
                          setState(() => _filter = entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                if (_visible.isEmpty)
                  EmptyStateCard(
                    icon: Icons.event_available_rounded,
                    title: 'Aucune consultation trouvée',
                    message:
                        'Aucun dossier ne correspond au filtre « ${_filters[_filter]} ». Changez de filtre ou revenez plus tard.',
                  )
                else
                  ..._visible.map(_tile),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  Widget _tile(ConsultationModel consultation) {
    final isPending = consultation.status == 'en_attente';
    final isLive = consultation.status == 'en_cours';
    final acting = _actingId == consultation.id;
    final patientName = consultation.patientName.isNotEmpty
        ? consultation.patientName
        : 'Patient #${consultation.patientId}';
    final diagnosis = (consultation.diagnosis != null && consultation.diagnosis!.trim().isNotEmpty)
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
            color: (isLive ? AppColors.primary : Colors.black).withValues(alpha: 0.05),
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
            .then((_) => _load()),
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
                          patientName[0].toUpperCase(),
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
                          child: _PulsingDot(),
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
                                color: AppColors.primaryContainer.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.2),
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
                          tooltip: isPending ? 'Lancer en vidéo' : 'Rejoindre la vidéo',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.secondary.withValues(alpha: 0.08),
                          ),
                          color: AppColors.secondary,
                          icon: const Icon(Icons.videocam_rounded, size: 20),
                          onPressed: () => VideoConsultation.launch(
                            context,
                            consultation,
                            startIfNeeded: isPending,
                          ).then((_) => _load()),
                        ),
                        const SizedBox(width: 6),
                      ],
                      StatusChip(status: consultation.status),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            color: isLive ? AppColors.primary : AppColors.textSecondary,
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
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: acting ? null : () => _accept(consultation),
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
                        onPressed: acting ? null : () => _decline(consultation),
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

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
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

class _DeclineDialog extends StatefulWidget {
  final String patientName;

  const _DeclineDialog({required this.patientName});

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
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
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(_selectedReason),
          child: const Text('Confirmer le refus'),
        ),
      ],
    );
  }
}

