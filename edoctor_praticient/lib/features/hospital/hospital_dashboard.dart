import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/hospital_model.dart';
import '../../data/models/nurse_visit_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import 'staff_screen.dart';
import 'nurse_visits_screen.dart';
import 'activity_screen.dart';
import '../common_notifications_screen.dart';
import 'hospital_profile_screen.dart';

/// Tableau de bord admin hôpital : effectifs + visites + établissement.
class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});
  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  UserModel? _user;
  HospitalModel? _hospital;
  Map<String, dynamic>? _staff;
  List<NurseVisitModel> _visits = [];
  Map<String, dynamic> _dashboard = {};
  int _notifCount = 0;
  Timer? _notificationTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshNotificationCount(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final hospital = await ApiService.getMyHospital();
      final staff = await ApiService.getHospitalStaff();
      final dashboard = await ApiService.getHospitalDashboard();
      final notifications = await ApiService.getNotifications();
      List<NurseVisitModel> visits = [];
      try {
        visits = await ApiService.getNurseVisits(hospital.id);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _user = user;
        _hospital = hospital;
        _staff = staff;
        _visits = visits;
        _dashboard = dashboard;
        _notifCount = notifications.where((item) => !item.isRead).length;
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final doctors = intOrNull(
        _dashboard['doctors_count'] ??
            (_staff?['doctors'] as List?)?.length ??
            _hospital?.doctors.length);
    final nurses = intOrNull(
        _dashboard['nurses_count'] ??
            (_staff?['nurses'] as List?)?.length ??
            _hospital?.nurses.length);
    final pending = intOrNull(_dashboard['pending_home_visits'] ??
        _visits.where((v) => v.status == 'en_attente').length);
    final today = intOrNull(_dashboard['today_consultations'] ?? 0);
    final ongoing = intOrNull(_dashboard['ongoing_consultations'] ?? 0);
    final doneVisits = intOrNull(_dashboard['completed_home_visits'] ?? 0);

    return ResponsiveShell(
      title: _hospital?.name ?? 'Mon hôpital',
      subtitle: _hospital == null
          ? 'Chargement de votre établissement…'
          : 'Administration · ${_user?.name ?? ''} · établissement ${_hospital!.status == 'verifie' ? 'vérifié' : 'en attente de vérification'}',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.hospital(
        userName: _user?.name ?? 'Administrateur',
        hospitalName: _hospital?.name,
        hospitalId: _user?.hospitalId ?? _hospital?.id ?? 0,
        currentSection: NavSection.dashboard,
        onLogout: _logout,
      ),
      actions: [_notifButton(context)],
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_hospital?.status == 'en_attente')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            color: AppColors.warning, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Dossier en cours de vérification par eDoctor. Vous pouvez déjà ajouter médecins et infirmiers.',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatCard(
                      icon: Icons.medication_rounded,
                      label: 'Médecins',
                      value: doctors,
                      color: AppColors.primary,
                    ),
                    StatCard(
                      icon: Icons.medical_services_rounded,
                      label: 'Infirmiers',
                      value: nurses,
                      color: AppColors.secondary,
                      tint: AppColors.secondary,
                    ),
                    StatCard(
                      icon: Icons.calendar_month_rounded,
                      label: 'Consultations du jour',
                      value: today,
                      color: AppColors.primary,
                    ),
                    StatCard(
                      icon: Icons.sensors_rounded,
                      label: 'Consultations en cours',
                      value: ongoing,
                      color: AppColors.primaryHover,
                    ),
                    StatCard(
                      icon: Icons.home_repair_service_rounded,
                      label: 'Visites en attente',
                      value: pending,
                      color: AppColors.warning,
                    ),
                    StatCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Visites terminées',
                      value: doneVisits,
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _actionCard(
                          icon: Icons.medical_services_outlined,
                          color: AppColors.primary,
                          title: 'Personnel soignant',
                          caption:
                              '$doctors médecin(s) · $nurses infirmier(s) affilié(s) à votre établissement.',
                          buttonLabel: 'Gérer le personnel',
                          onPressed: () => Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                    builder: (_) => const StaffScreen()),
                              )
                              .then((_) => _load()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionCard(
                          icon: Icons.home_repair_service_rounded,
                          color: AppColors.warning,
                          title: 'Soins à domicile',
                          caption:
                              '${_visits.length} visite(s) demandée(s) · $pending en attente d’affectation.',
                          buttonLabel: 'Voir les visites',
                          onPressed: _hospital == null
                              ? null
                              : () => Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) => NurseVisitsScreen(
                                          hospitalId: _hospital!.id,
                                        ),
                                      ),
                                    )
                                    .then((_) => _load()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HospitalProfileScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.apartment_rounded),
                        label: const Text('Fiche de l’établissement'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HospitalActivityScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Activité de l’hôpital'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                SectionHeader(
                  title: 'Établissement',
                  actionLabel: 'Modifier',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const HospitalProfileScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Wrap(
                    spacing: 34,
                    runSpacing: 16,
                    children: [
                      InfoTile('Nom', _hospital?.name, Icons.local_hospital_outlined),
                      InfoTile('Adresse', _hospital?.address,
                          Icons.location_on_outlined),
                      InfoTile('E-mail officiel', _hospital?.officialEmail,
                          Icons.email_outlined),
                      InfoTile('Téléphone', _hospital?.phone,
                          Icons.phone_outlined),
                      InfoTile(
                        'Tarif consultation',
                        '${_hospital?.consultationFee.toInt() ?? 3000} FCFA',
                        Icons.payments_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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

  PraticienNav _nav() => PraticienNav.hospital(
        userName: _user?.name ?? 'Administrateur',
        hospitalName: _hospital?.name,
        hospitalId: _user?.hospitalId ?? _hospital?.id ?? 0,
        onLogout: _logout,
      );

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String caption,
    required String buttonLabel,
    VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.45),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
