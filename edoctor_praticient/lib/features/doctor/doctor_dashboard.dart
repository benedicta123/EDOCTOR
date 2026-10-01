import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/prescription_pdf_service.dart';
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
import '../common_notifications_screen.dart';

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
    _consultationPolling = Timer.periodic(const Duration(seconds: 15), (_) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _refreshNotificationCount();
      _silentRefresh();
    });
  }

  /// Les nouvelles demandes de consultation apparaissent seules,
  /// sans spinner ni recharge visible. Une alerte discrète signale
  /// chaque nouvelle demande entrante.
  Future<void> _silentRefresh() async {
    try {
      final consultations = await ApiService.getConsultations();
      final dashboard = await ApiService.getDoctorDashboard();
      if (!mounted) return;
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
    final pending = intOrNull(
        _dashboard['pending_consultations'] ?? _count('en_attente'));
    final done =
        intOrNull(_dashboard['completed_consultations'] ?? _count('terminee'));
    final patients = intOrNull(_dashboard['patients_followed'] ?? 0);
    final rx = intOrNull(
        _dashboard['prescriptions_issued'] ?? _prescriptions.length);

    final recent = _consultations.take(3).toList();

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
        _notifButton(context),
      ],
      child: _loading
          ? const _DashboardSkeleton()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final crossAxisCount =
                        w >= 980 ? 4 : (w >= 540 ? 2 : 1);
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: w >= 980 ? 1.35 : 1.3,
                      children: [
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

  Widget _consultationTile(ConsultationModel c) {
    final isLive = c.status == 'en_cours';
    final isPending = c.status == 'en_attente';

    PrescriptionModel? p = c.prescription;
    if (p == null) {
      try {
        p = _prescriptions.firstWhere((item) => item.consultationId == c.id);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête Consultation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPending ? AppColors.warningLight : AppColors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isPending
                      ? AppColors.surface
                      : AppColors.primaryContainer,
                  child: Text(
                    c.patientName.isNotEmpty
                        ? c.patientName[0].toUpperCase()
                        : 'P',
                    style: TextStyle(
                      color: isPending ? AppColors.warning : AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.patientName.isEmpty
                            ? 'Patient #${c.patientId}'
                            : c.patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Consultation ${c.displayCode} · ${formatDateTime(c.scheduledAt)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
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
                    onPressed: () => VideoConsultation.launch(context, c,
                            startIfNeeded: isPending)
                        .then((_) => _load()),
                  ),
                  const SizedBox(width: 4),
                ],
                StatusChip(status: c.status),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Ouvrir le dossier',
                  icon: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 15, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ConsultationDetailScreen(consultation: c),
                        ),
                      )
                      .then((_) => _load()),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // Bloc Ordonnance liée
          Padding(
            padding: const EdgeInsets.all(16),
            child: p != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Ordonnance + Export PDF
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORD-2026-${p.id.toString().padLeft(4, '0')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Émise le ${p.formattedDate}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusChip(status: p.status),
                          const SizedBox(width: 8),
                          // Bouton d'exportation PDF
                          IconButton.filledTonal(
                            tooltip: 'Imprimer / Exporter l\'ordonnance en PDF',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.print_rounded, size: 18),
                            onPressed: () async {
                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Préparation et export de l\'ordonnance en PDF...'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                await PrescriptionPdfService.printPrescription(
                                    p!);
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Erreur lors de l\'export : $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Fiche Patient & Établissement
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${p.patientName} (${p.patientAge})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_hospital_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Dr. ${p.doctorName.isNotEmpty ? p.doctorName : (_user?.name ?? 'Médecin')} • ${p.hospitalName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Diagnostic clinique préalable
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textPrimary),
                                  children: [
                                    const TextSpan(
                                      text: 'Diagnostic clinique préalable : ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    TextSpan(
                                      text: p.diagnosis.isNotEmpty
                                          ? p.diagnosis
                                          : (c.diagnosis?.isNotEmpty == true
                                              ? c.diagnosis!
                                              : 'Consultation de suivi médical'),
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Médicaments prescrits
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Médicaments prescrits (${p.items.length}) :',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (p.homeCareRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.home_outlined,
                                      size: 12, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Soins à domicile',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (p.items.isEmpty)
                        const Text(
                          'Aucun médicament enregistré dans l\'ordonnance.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        )
                      else
                        ...p.items.map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'Qté: ${item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.medicationName +
                                        (item.dosageInstructions.isNotEmpty
                                            ? ' (${item.dosageInstructions})'
                                            : ''),
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
                        ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.diagnosis != null && c.diagnosis!.isNotEmpty
                                ? 'Diagnostic : ${c.diagnosis} (Ordonnance non encore émise)'
                                : 'Aucune ordonnance émise pour cette consultation.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => ConsultationDetailScreen(
                                      consultation: c),
                                ),
                              )
                              .then((_) => _load()),
                          child: const Text('Ouvrir',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
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
