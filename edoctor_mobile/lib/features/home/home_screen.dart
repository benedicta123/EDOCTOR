import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/patient_bottom_nav.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/utils/format.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/prescription_model.dart';
import '../../data/models/user_model.dart';
import '../doctors/consultation_screen.dart';
import '../doctors/find_doctor_screen.dart';
import '../doctors/my_consultations_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../prescriptions/prescriptions_screen.dart';
import '../home_care/home_care_screen.dart';
import '../dossier/patient_dossier_screen.dart';
import '../profile/patient_profile_screen.dart';
import '../lab_examinations/lab_examinations_screen.dart';
import '../claims/claims_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel? user;

  const HomeScreen({super.key, this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _currentNavIndex = 0;
  List<ConsultationModel> _consultations = [];
  List<PatientPrescription> _prescriptions = [];
  int _unreadCount = 0;
  Timer? _statusPoll;
  bool _pollingStatus = false;
  bool _statusPrimed = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _statusPoll = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshStatus(),
    );
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus({bool force = false}) async {
    if (!mounted) return;
    if (_pollingStatus && !force) return;
    _pollingStatus = true;
    try {
      final consultations = await ApiService.getMyConsultations();
      final notifs = await ApiService.getNotifications();
      List<PatientPrescription> prescriptions = _prescriptions;
      try {
        prescriptions = await ApiService.getPrescriptions();
      } catch (_) {}
      if (!mounted) return;
      final previousActive = _consultations
          .where((c) => c.isActive)
          .map((c) => c.id)
          .toSet();
      final previousRxIds = _prescriptions.map((p) => p.id).toSet();
      setState(() {
        _consultations = consultations;
        _prescriptions = prescriptions;
        _unreadCount = notifs.where((n) => !n.isRead).length;
      });
      final newRx = prescriptions.where(
        (p) => !previousRxIds.contains(p.id),
      );
      final primed = _statusPrimed;
      _statusPrimed = true;
      if (newRx.isNotEmpty && mounted && primed) {
        final rx = newRx.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nouvelle ordonnance de ${doctorDisplay(rx.doctorName)} — Voir',
            ),
            backgroundColor: AppColors.secondary,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Voir',
              textColor: Colors.white,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PrescriptionsScreen()),
              ),
            ),
          ),
        );
      }
      final newlyActive = consultations.where(
        (c) => c.isActive && !previousActive.contains(c.id),
      );
      if (newlyActive.isNotEmpty && mounted && primed) {
        final c = newlyActive.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Votre consultation avec ${doctorDisplay(c.doctorName)} a commencé — Rejoindre',
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Rejoindre',
              textColor: Colors.white,
              onPressed: () => _openConsultation(c),
            ),
          ),
        );
      }
    } catch (_) {
    } finally {
      _pollingStatus = false;
    }
  }

  void _openConsultation(ConsultationModel c) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PatientConsultationScreen(consultation: c),
          ),
        )
        .then((_) => _refreshStatus(force: true));
  }

  String get _firstName {
    final fullName = widget.user?.name ?? 'Koffi';
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : 'Koffi';
  }

  void _onNavSelected(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FindDoctorScreen()),
      );
    } else if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PatientDossierScreen()),
      );
    } else if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PatientProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 16,
        title: const Row(
          children: [
            AppLogo(width: 130, height: 42),
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const PatientNotificationsScreen(),
                        ),
                      )
                      .then((_) => _refreshStatus());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Salutation personnalisée
            Text(
              'Bonjour, $_firstName',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Comment vous sentez-vous aujourd\'hui ?',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // Action Principale : Consulter un médecin — bannière élargie avec photo médecin
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FindDoctorScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: double.infinity,
                height: 165,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF529927),
                      Color(0xFF529927),
                      Color(0xFF529927),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF529927).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      // Doctor image — right side
                      Positioned(
                        right: 0,
                        bottom: 0,
                        top: 0,
                        child: Image.asset(
                          'assets/images/doctor_banner.jpg',
                          width: 175,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0.2, -0.3),
                        ),
                      ),

                      // Heart pill button (exact replica of reference on the right)
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.28),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ),

                      // Subtle gradient fade over photo to blend text side
                      Positioned(
                        right: 120,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                const Color(0xFF529927),
                                const Color(0xFF529927).withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Left Content — Exact wording & style from reference
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 140, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Better Care, Better Life',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Consulter un\nmédecin',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Prenez rendez-vous, suivi et consultations médicales.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.82),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 26),

            _buildConsultationsCard(),

            const SizedBox(height: 26),

            // Section titre grille
            const Text(
              'Accès rapide',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),

            // Grille Bento (4 accès rapides) — style premium inspiré des références
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _buildBentoItem(
                  icon: Icons.shopping_bag_rounded,
                  title: 'Mes commandes',
                  subtitle: 'Suivi & historique',
                  accentColor: const Color(0xFF529927),
                  bgColor: const Color(0xFFEAF5DF),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrdersScreen()),
                    );
                  },
                ),
                _buildBentoItem(
                  icon: Icons.receipt_long_rounded,
                  title: 'Prescriptions',
                  subtitle: 'Mes ordonnances',
                  cardBgColor: const Color(0xFF529927),
                  isDark: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrescriptionsScreen()),
                    );
                  },
                ),
                _buildBentoItem(
                  icon: Icons.forum_rounded,
                  title: 'Historique',
                  subtitle: 'Conversations médecin',
                  cardBgColor: const Color(0xFF059669),
                  isDark: true,
                  onTap: _openHistory,
                ),
                _buildBentoItem(
                  icon: Icons.medical_information_rounded,
                  title: 'Soins domicile',
                  subtitle: 'Infirmier chez vous',
                  accentColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF3E8FF),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HomeCareScreen()),
                    );
                  },
                ),
                _buildBentoItem(
                  icon: Icons.biotech_rounded,
                  title: 'Bilans & Examens',
                  subtitle: 'Analyses & imagerie',
                  accentColor: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFE0F2FE),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LabExaminationsScreen()),
                    );
                  },
                ),
                _buildBentoItem(
                  icon: Icons.support_agent_rounded,
                  title: 'Assistance',
                  subtitle: 'Réclamations & litiges',
                  cardBgColor: const Color(0xFF15803D),
                  isDark: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ClaimsScreen()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Activité récente — dernière activité réelle (ordonnance,
            // consultation ou notification), jamais de contenu figé.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activité récente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _openHistory,
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text(
                    'Voir tout',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildRecentActivity(),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: PatientBottomNav(
        currentIndex: _currentNavIndex,
        onTabSelected: _onNavSelected,
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
              builder: (_) => const MyConsultationsScreen()),
        )
        .then((_) => _refreshStatus());
  }

  Widget _buildConsultationsCard() {
    final active = _consultations
        .where((c) => (c.isActive || c.isPending) && c.status != 'annulee')
        .toList();
    final done =
        _consultations.where((c) => c.isDone).toList();
    final joinable = active.where((c) => c.isActive).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
          Row(
            children: [
              const Icon(Icons.forum_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Conversations & Téléconsultations',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (joinable.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${joinable.length} EN DIRECT',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // S'il y a des consultations actives / en attente
          if (active.isNotEmpty) ...[
            ...active.take(2).map((c) {
              final isUnpaid = c.isPending && !c.isPaid;
              return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: c.isActive
                        ? AppColors.primaryContainer
                        : isUnpaid
                            ? AppColors.warningLight.withValues(alpha: 0.5)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.isActive
                          ? AppColors.primary
                          : isUnpaid
                              ? AppColors.warning
                              : AppColors.border,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openConsultation(c),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c.isActive
                                    ? AppColors.primary
                                    : isUnpaid
                                        ? AppColors.warning
                                        : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                c.isActive
                                    ? Icons.videocam_rounded
                                    : isUnpaid
                                        ? Icons.payment_rounded
                                        : Icons.hourglass_top_rounded,
                                color: c.isActive || isUnpaid
                                    ? Colors.white
                                    : AppColors.warning,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.doctorName.isNotEmpty
                                        ? '${doctorDisplay(c.doctorName)} (${c.displayCode})'
                                        : 'Consultation ${c.displayCode}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    c.isActive
                                        ? 'En cours — touchez pour rejoindre'
                                        : isUnpaid
                                            ? 'Paiement en attente (${c.totalAmount.toInt()} FCFA) — touchez pour régler'
                                            : 'Demande transmise — en attente du médecin…',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.isActive
                                          ? AppColors.primary
                                          : isUnpaid
                                              ? const Color(0xFFB45309)
                                              : AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
            }),
          ],

          // Bannière / Bouton permanent d'accès à l'historique complet des conversations
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openHistory,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.mark_chat_read_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              done.isNotEmpty
                                  ? '${done.length} consultation(s) terminée(s)'
                                  : 'Relire mes conversations avec les médecins',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Accéder à tous vos échanges, conseils et comptes-rendus',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  Widget _buildRecentActivity() {
    final live = _consultations.where((c) => c.isActive).toList();
    PatientPrescription? lastRx;
    for (final p in _prescriptions) {
      if (lastRx == null) {
        lastRx = p;
        continue;
      }
      final a = _parseDate(p.createdAt);
      final b = _parseDate(lastRx.createdAt);
      if (a != null && (b == null || a.isAfter(b))) lastRx = p;
    }
    ConsultationModel? lastClosed;
    for (final c in _consultations.where((c) => c.isDone)) {
      if (lastClosed == null) {
        lastClosed = c;
        continue;
      }
      final a = _parseDate(c.endedAt ?? c.createdAt);
      final b = _parseDate(lastClosed.endedAt ?? lastClosed.createdAt);
      if (a != null && (b == null || a.isAfter(b))) lastClosed = c;
    }

    if (live.isNotEmpty) {
      final c = live.first;
      return _activityCard(
        icon: Icons.videocam_rounded,
        iconBg: AppColors.primaryContainer,
        iconColor: AppColors.primary,
        badge: 'EN COURS',
        badgeBg: AppColors.primary,
        badgeColor: Colors.white,
        date: relativeLabel(c.startedAt ?? c.createdAt),
        title: 'Consultation avec ${doctorDisplay(c.doctorName)}',
        message: 'Votre consultation a commencé. Rejoignez la vidéo ou poursuivez la discussion.',
        actionLabel: 'Rejoindre la consultation',
        onAction: () => _openConsultation(c),
      );
    }

    final rxDate = _parseDate(lastRx?.createdAt);
    final closedDate =
        _parseDate(lastClosed?.endedAt ?? lastClosed?.createdAt);
    final rx = lastRx;
    if (rx != null &&
        (closedDate == null ||
            (rxDate != null && !rxDate.isBefore(closedDate)))) {
      return _activityCard(
        icon: Icons.receipt_long_rounded,
        iconBg: const Color(0xFFFED7AA),
        iconColor: const Color(0xFFC2410C),
        badge: rx.isActive ? 'À TRAITER' : 'ARCHIVÉE',
        badgeBg: const Color(0xFFFED7AA),
        badgeColor: const Color(0xFFC2410C),
        date: relativeLabel(rx.createdAt),
        title: 'Ordonnance de ${doctorDisplay(rx.doctorName)}',
        message:
            '${rx.items.length} médicament(s) prescrit(s) — consultation ${rx.consultationDisplayCode}.',
        actionLabel: 'Voir l’ordonnance',
        onAction: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const PrescriptionsScreen()),
          );
        },
      );
    }

    if (lastClosed != null) {
      final c = lastClosed;
      return _activityCard(
        icon: Icons.history_rounded,
        iconBg: AppColors.secondaryContainer,
        iconColor: AppColors.secondary,
        badge: c.status == 'terminee' ? 'TERMINÉE' : 'ANNULÉE',
        badgeBg: AppColors.surfaceDim,
        badgeColor: AppColors.textSecondary,
        date: relativeLabel(c.endedAt ?? c.createdAt),
        title: 'Consultation avec ${doctorDisplay(c.doctorName)}',
        message: 'La discussion reste disponible en lecture seule.',
        actionLabel: 'Relire la discussion',
        onAction: () => _openConsultation(c),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FindDoctorScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.medical_services_outlined,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aucune consultation récente',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Prenez rendez-vous avec un médecin disponible en direct.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String badge,
    required Color badgeBg,
    required Color badgeColor,
    required String date,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (date.isNotEmpty)
                                Text(
                                  date,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            message,
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
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          actionLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBentoItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color accentColor = AppColors.primary,
    Color bgColor = AppColors.primaryContainer,
    Color? cardBgColor,
    bool isDark = false,
  }) {
    final effectiveCardBg = cardBgColor ?? AppColors.surface;
    final effectiveTitleColor = isDark ? Colors.white : AppColors.textPrimary;
    final effectiveSubColor = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textMuted;
    final effectiveIconColor = isDark ? Colors.white : accentColor;
    final effectiveIconBg = isDark ? Colors.white.withValues(alpha: 0.22) : bgColor;

    return Container(
      decoration: BoxDecoration(
        color: effectiveCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? effectiveCardBg.withValues(alpha: 0.35)
                : accentColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: effectiveIconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: effectiveIconColor,
                    size: 22,
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: effectiveTitleColor,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: effectiveSubColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
