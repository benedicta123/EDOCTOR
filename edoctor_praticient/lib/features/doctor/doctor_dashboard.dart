import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/incoming_call_watcher.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/user_model.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/prescription_model.dart';
import '../auth/login_screen.dart';
import 'consultation_detail_screen.dart';
import 'consultations_screen.dart';
import 'video_consultation_screen.dart';
import 'widgets/consultation_card.dart';
import '../common_notifications_screen.dart';
import '../wallet/praticien_wallet_screen.dart';

/// Tableau de bord médecin : statistiques + consultations + ordonnances récentes.
/// Heartbeat toutes les 45 s pour la présence en ligne.
class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});
  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  UserModel? _user;
  List<ConsultationModel> _consultations = [];
  List<PrescriptionModel> _prescriptions = [];
  int _notifCount = 0;
  Map<String, dynamic> _dashboard = {};
  bool _loading = true;
  Timer? _heartbeat;
  Timer? _consultationPolling;
  Set<int> _knownPendingIds = {};
  bool _dashboardReady = false;

  @override
  void initState() {
    super.initState();
    _load();
    IncomingCallWatcher.instance.start();
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      ApiService.heartbeat();
    });
    _consultationPolling = Timer.periodic(const Duration(seconds: 3), (_) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _refreshNotificationCount();
      _silentRefresh();
    });
  }

  int _compareConsultations(ConsultationModel a, ConsultationModel b) {
    int priority(String s) {
      if (s == 'en_cours') return 0;
      if (s == 'en_attente') return 1;
      return 2;
    }

    final pa = priority(a.status);
    final pb = priority(b.status);
    if (pa != pb) return pa.compareTo(pb);
    return (b.createdAt ?? '').compareTo(a.createdAt ?? '');
  }

  /// Les nouvelles demandes de consultation apparaissent seules,
  /// sans spinner ni recharge visible. Une alerte discrète signale
  /// chaque nouvelle demande entrante.
  Future<void> _silentRefresh() async {
    try {
      final consultations = await ApiService.getConsultations();
      final dashboard = await ApiService.getDoctorDashboard();
      if (!mounted) return;
      consultations.sort(_compareConsultations);
      final pendingIds = consultations
          .where((c) => c.status == 'en_attente')
          .map((c) => c.id)
          .toSet();
      final freshIds = pendingIds.difference(_knownPendingIds);
      setState(() {
        _consultations = consultations;
        _dashboard = dashboard;
        _knownPendingIds = pendingIds;
      });
      if (_dashboardReady && freshIds.isNotEmpty && mounted) {
        final first = consultations.firstWhere((c) => c.id == freshIds.first);
        final name = first.patientName.isEmpty
            ? 'Patient #${first.patientId}'
            : first.patientName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nouvelle demande de consultation de $name — Voir'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Voir',
              textColor: Colors.white,
              onPressed: () => Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, anim1, anim2) =>
                      const DoctorConsultationsScreen(),
                  transitionDuration: Duration.zero,
                ),
              ),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _refreshNotificationCount() async {
    try {
      final notifications = await ApiService.getNotifications();
      if (mounted) {
        setState(
          () =>
              _notifCount = notifications.where((item) => !item.isRead).length,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _consultationPolling?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final consultations = await ApiService.getConsultations();
      final prescriptions = await ApiService.getPrescriptions();
      final notifs = await ApiService.getNotifications();
      final dashboard = await ApiService.getDoctorDashboard();
      if (!mounted) return;
      consultations.sort(_compareConsultations);
      setState(() {
        _user = user;
        _consultations = consultations;
        _prescriptions = prescriptions;
        _notifCount = notifs.where((n) => !n.isRead).length;
        _dashboard = dashboard;
        _knownPendingIds = consultations
            .where((c) => c.status == 'en_attente')
            .map((c) => c.id)
            .toSet();
        _dashboardReady = true;
        _loading = false;
      });
      ApiService.heartbeat();
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

  int _count(String s) => _consultations.where((c) => c.status == s).length;

  bool _updatingStatus = false;

  Future<void> _changeAvailability(String status) async {
    setState(() => _updatingStatus = true);
    try {
      await ApiService.updateDoctorAvailability(status);
      final user = await StorageService.getUser();
      if (user != null) {
        final updated = UserModel(
          id: user.id,
          name: user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          licenseNumber: user.licenseNumber,
          specialty: user.specialty,
          availabilityStatus: status,
          hospitalId: user.hospitalId,
          dateOfBirth: user.dateOfBirth,
          address: user.address,
        );
        await StorageService.saveUser(updated);
        if (mounted) setState(() => _user = updated);
      }
      if (mounted) {
        final label = status == 'au_bloc'
            ? 'Au bloc opératoire'
            : status == 'disponible'
                ? 'Disponible'
                : 'Indisponible';
        showMsg(context, 'Statut médical mis à jour : $label');
      }
    } catch (e) {
      if (mounted) {
        showMsg(context, e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _logout() async {
    IncomingCallWatcher.instance.stop();
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ongoing = intOrNull(
        _dashboard['ongoing_consultations'] ?? _count('en_cours'));
    final pending = intOrNull(
        _dashboard['pending_consultations'] ?? _count('en_attente'));
    final done =
        intOrNull(_dashboard['completed_consultations'] ?? _count('terminee'));
    final patients = intOrNull(_dashboard['patients_followed'] ?? 0);
    final rx = intOrNull(
        _dashboard['prescriptions_issued'] ?? _prescriptions.length);

    final ongoingList =
        _consultations.where((c) => c.status == 'en_cours').toList();
    final recent = _consultations.take(5).toList();

    return ResponsiveShell(
      title: 'Bonjour ${_user != null ? doctorDisplay(_user!.name) : 'Docteur'}',
      subtitle:
          '${_user?.specialty?.isNotEmpty == true ? _user!.specialty! : 'Médecin'} · ${_consultations.length} consultation(s) au total',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.doctor(
        userName: _user?.name ?? 'Docteur',
        userSpecialty: _user?.specialty,
        currentSection: NavSection.dashboard,
        consultationsPending: _count('en_attente'),
        onLogout: _logout,
      ),
      actions: [
        IconButton(
          tooltip: 'Mon Portefeuille',
          icon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PraticienWalletScreen(initialIsDoctor: true)),
          ),
        ),
        _notifButton(context),
      ],
      child: _loading
          ? const _DashboardSkeleton()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ongoingList.isNotEmpty) ...[
                  ...ongoingList.map(_buildLiveOngoingBanner),
                ],
                _buildAvailabilityControlCard(ongoingList.isNotEmpty),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final hasOngoing = ongoing > 0;
                    final crossAxisCount = hasOngoing
                        ? (w >= 1150 ? 5 : (w >= 700 ? 3 : (w >= 480 ? 2 : 1)))
                        : (w >= 980 ? 4 : (w >= 540 ? 2 : 1));
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: w >= 980 ? 1.35 : 1.3,
                      children: [
                        if (hasOngoing)
                          StatCard(
                            icon: Icons.videocam_rounded,
                            label: 'En cours en direct',
                            value: ongoing,
                            color: AppColors.error,
                            width: null,
                          ),
                        StatCard(
                          icon: Icons.hourglass_top_rounded,
                          label: 'Consultations en attente',
                          value: pending,
                          color: AppColors.warning,
                          width: null,
                        ),
                        StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Consultations terminées',
                          value: done,
                          color: AppColors.secondary,
                          width: null,
                        ),
                        StatCard(
                          icon: Icons.people_alt_rounded,
                          label: 'Patients suivis',
                          value: patients,
                          color: AppColors.primary,
                          width: null,
                        ),
                        StatCard(
                          icon: Icons.receipt_long_rounded,
                          label: 'Ordonnances émises',
                          value: rx,
                          color: AppColors.primaryHover,
                          width: null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 26),
                SectionHeader(
                  title: 'Consultations récentes',
                  actionLabel: 'Tout voir',
                  onAction: () => Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (context, anim1, anim2) =>
                          const DoctorConsultationsScreen(),
                      transitionDuration: Duration.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.event_available_rounded,
                    title: 'Aucune consultation',
                    message:
                        'Les demandes de consultation de vos patients apparaîtront ici dès leur envoi.',
                  )
                else
                  ...recent.map(_consultationTile),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _notifButton(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NotificationsScreen(nav: _nav())),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined, color: Colors.white),
          if (_notifCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                constraints: const BoxConstraints(minWidth: 17),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$_notifCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  PraticienNav _nav() => PraticienNav.doctor(
        userName: _user?.name ?? 'Docteur',
        userSpecialty: _user?.specialty,
        onLogout: _logout,
      );

  Widget _buildLiveOngoingBanner(ConsultationModel c) {
    final patientName = c.patientName.isNotEmpty
        ? c.patientName
        : 'Patient #${c.patientId}';
    final elapsed = relativeLabel(c.startedAt ?? c.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record,
                          size: 10, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'EN DIRECT · CONSULTATION EN COURS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (elapsed.isNotEmpty)
                  Text(
                    'Démarrée $elapsed',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dossier ${c.displayCode} · Patient #${c.patientId}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => VideoConsultation.launch(context, c,
                          startIfNeeded: false)
                      .then((_) => _load()),
                  icon: const Icon(Icons.videocam_rounded, size: 18),
                  label: const Text('Rejoindre l\'appel vidéo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ConsultationDetailScreen(consultation: c),
                        ),
                      )
                      .then((_) => _load()),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Ouvrir le dossier / Diagnostic & Rx'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int? _actingId;

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
      builder: (ctx) => DeclineDialog(patientName: c.patientName),
    );
    if (reason == null) return;

    IncomingCallWatcher.instance.markHandled(c.id);
    setState(() => _actingId = c.id);
    try {
      await ApiService.consultationAction(c.id, 'decline', reason: reason);
      if (!mounted) return;
      showMsg(context,
          'Consultation ${c.displayCode} refusée. Le patient a été notifié.');
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

  Widget _consultationTile(ConsultationModel c) {
    return ConsultationCard(
      consultation: c,
      onRefresh: _load,
      actingId: _actingId,
      onAccept: _accept,
      onDecline: _decline,
    );
  }

  Widget _buildAvailabilityControlCard(bool hasOngoingConsultation) {
    final rawStatus = _user?.availabilityStatus ?? 'disponible';
    final effectiveStatus =
        hasOngoingConsultation ? 'en_consultation' : rawStatus;

    Color badgeColor;
    IconData badgeIcon;
    String statusTitle;
    String statusSubtitle;

    if (effectiveStatus == 'en_consultation') {
      badgeColor = AppColors.error;
      badgeIcon = Icons.sensors_rounded;
      statusTitle = 'En consultation vidéo';
      statusSubtitle =
          'Vous êtes actuellement en ligne avec un patient. Les nouvelles demandes sont bloquées.';
    } else if (effectiveStatus == 'au_bloc') {
      badgeColor = AppColors.warning;
      badgeIcon = Icons.local_hospital_rounded;
      statusTitle = 'Au bloc opératoire';
      statusSubtitle =
          'Vos téléconsultations sont suspendues. Le bouton est désactivé pour les patients.';
    } else if (effectiveStatus == 'indisponible') {
      badgeColor = Colors.blueGrey;
      badgeIcon = Icons.do_not_disturb_on_rounded;
      statusTitle = 'Indisponible';
      statusSubtitle =
          'Vous êtes actuellement hors service pour les téléconsultations.';
    } else {
      badgeColor = AppColors.success;
      badgeIcon = Icons.check_circle_rounded;
      statusTitle = 'Disponible pour téléconsultation';
      statusSubtitle =
          'Votre profil est visible en ligne. Vous recevez directement les appels des patients.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: badgeColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(badgeIcon, color: badgeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          statusTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                        if (_updatingStatus) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill(
                label: 'Disponible',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                isSelected: effectiveStatus == 'disponible',
                onTap: () => _changeAvailability('disponible'),
              ),
              _buildStatusPill(
                label: 'Au bloc opératoire',
                icon: Icons.local_hospital_rounded,
                color: AppColors.warning,
                isSelected: effectiveStatus == 'au_bloc',
                onTap: () => _changeAvailability('au_bloc'),
              ),
              _buildStatusPill(
                label: 'Indisponible',
                icon: Icons.do_not_disturb_on_outlined,
                color: Colors.blueGrey,
                isSelected: effectiveStatus == 'indisponible',
                onTap: () => _changeAvailability('indisponible'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _updatingStatus || isSelected ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Squelette de chargement : cartes fantômes plutôt qu’un spinner figé.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget ghost(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.surfaceDim.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.filled(
            4,
            Container(
              width: 170,
              height: 118,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ghost(38, 38),
                    const Spacer(),
                    ghost(64, 22),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        ghost(180, 20),
        const SizedBox(height: 14),
        ...List.filled(3, Padding(padding: const EdgeInsets.only(bottom: 10), child: ghost(double.infinity, 68))),
      ],
    );
  }
}
