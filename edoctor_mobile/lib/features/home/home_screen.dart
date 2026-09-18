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
import '../medical_history/medical_history_screen.dart';
import '../home_care/home_care_screen.dart';
import '../dossier/patient_dossier_screen.dart';
import '../profile/patient_profile_screen.dart';

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

  Future<void> _refreshStatus() async {
    if (!mounted || _pollingStatus) return;
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
              'Nouvelle ordonnance de Dr ${rx.doctorName} — Voir',
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
              'Votre consultation avec Dr ${c.doctorName} a commencé — Rejoindre',
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
        .then((_) => _refreshStatus());
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
                  accentColor: const Color(0xFF132A45),
                  bgColor: const Color(0xFFDCE6F2),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrescriptionsScreen()),
                    );
                  },
                ),
                _buildBentoItem(
                  icon: Icons.history_rounded,
                  title: 'Historique',
                  subtitle: 'Dossier médical',
                  accentColor: const Color(0xFF0369A1),
                  bgColor: const Color(0xFFE0F2FE),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MedicalHistoryScreen()),
                    );
                  },
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
              ],
            ),

            const SizedBox(height: 28),

            // Activité récente — dernière activité réelle (ordonnance,
            // consultation ou notification), jamais de contenu figé.
            const Text(
              'Activité récente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
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
        .where((c) => c.isActive || c.isPending)
        .toList();
    final done =
        _consultations.where((c) => c.isDone).toList();
    if (active.isEmpty && done.isEmpty) {
      return const SizedBox.shrink();
    }
    final joinable = active.where((c) => c.isActive).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Mes consultations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (joinable.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${joinable.length} À REJOINDRE',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (active.isEmpty)
            InkWell(
              onTap: _openHistory,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${done.length} consultation(s) terminée(s) — relire les discussions',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ...active.take(3).map((c) => InkWell(
                onTap: () => _openConsultation(c),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.isActive
                        ? AppColors.primaryContainer
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.isActive
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          c.isActive
                              ? Icons.videocam_rounded
                              : Icons.hourglass_top_rounded,
                          color: c.isActive
                              ? Colors.white
                              : AppColors.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.doctorName.isNotEmpty
                                  ? 'Dr. ${c.doctorName}'
                                  : 'Consultation #${c.id}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              c.isActive
                                  ? 'En cours — touchez pour rejoindre'
                                  : 'En attente d’acceptation…',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.isActive
                                    ? AppColors.primary
                                    : AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _openHistory,
              icon: const Icon(Icons.history_rounded, size: 16),
              label: const Text(
                'Voir tout l’historique',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
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
        title: 'Consultation avec Dr. ${c.doctorName}',
        message: 'Votre consultation a commencé. Rejoignez la vidéo ou poursuivez la discussion.',
        actionLabel: 'Rejoindre',
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
        title: 'Ordonnance de Dr. ${rx.doctorName}',
        message:
            '${rx.items.length} médicament(s) prescrit(s) — consultation #${rx.consultationId}.',
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
        title: 'Consultation avec Dr. ${c.doctorName}',
        message: 'La discussion reste disponible en lecture seule.',
        actionLabel: 'Relire la discussion',
        onAction: () => _openConsultation(c),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_available_rounded,
              color: AppColors.textMuted, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aucune activité pour le moment. Consultez un médecin pour démarrer votre suivi.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
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
            child: OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: AppColors.background,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 22,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
