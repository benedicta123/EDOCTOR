import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
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
    setState(() => _actingId = c.id);
    try {
      await ApiService.consultationAction(c.id, 'start');
      if (!mounted) return;
      showMsg(context, 'Consultation #${c.id} acceptée — en cours');
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isPending ? AppColors.warningLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? AppColors.warning : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isPending
                      ? AppColors.surface
                      : AppColors.primaryContainer,
                  child: Text(
                    consultation.patientName.isNotEmpty
                        ? consultation.patientName[0].toUpperCase()
                        : 'P',
                    style: TextStyle(
                      color:
                          isPending ? AppColors.warning : AppColors.primary,
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
            title: Text(
              consultation.patientName.isEmpty
                  ? 'Patient #${consultation.patientId}'
                  : consultation.patientName,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Consultation #${consultation.id} · ${formatDateTime(consultation.scheduledAt)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPending || isLive)
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
                    onPressed: () =>
                        VideoConsultation.launch(context, consultation,
                                startIfNeeded: isPending)
                            .then((_) => _load()),
                  ),
                StatusChip(status: consultation.status),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ],
            ),
            onTap: () => Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => ConsultationDetailScreen(
                      consultation: consultation,
                    ),
                  ),
                )
                .then((_) => _load()),
          ),
          if (isPending)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed:
                      acting ? null : () => _accept(consultation),
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
                  label: Text(
                      acting ? 'Acceptation…' : 'Accepter'),
                ),
              ),
            ),
        ],
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
