import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../features/doctor/doctor_dashboard.dart';
import '../../features/doctor/consultations_screen.dart';
import '../../features/doctor/patients_screen.dart';
import '../../features/doctor/prescriptions_screen.dart';
import '../../features/doctor/messages_screen.dart';
import '../../features/hospital/hospital_dashboard.dart';
import '../../features/hospital/hospital_profile_screen.dart';
import '../../features/hospital/staff_screen.dart';
import '../../features/hospital/nurse_visits_screen.dart';
import '../../features/hospital/activity_screen.dart';
import '../../features/profile/profile_screen.dart';

/// Sections de navigation praticien — une seule source de vérité
/// pour le menu latéral (docteur comme admin d'hôpital).
enum NavSection {
  dashboard,
  consultations,
  patients,
  prescriptions,
  messages,
  hospitalProfile,
  staff,
  nurseVisits,
  activity,
  profile,
}

/// Données de navigation portées par chaque écran.
class PraticienNav {
  final bool isDoctor;
  final String userName;
  final String? userSpecialty;
  final String? hospitalName;
  final int hospitalId;
  final NavSection? currentSection;
  final int consultationsPending;
  final VoidCallback onLogout;

  const PraticienNav({
    required this.isDoctor,
    required this.userName,
    this.userSpecialty,
    this.hospitalName,
    this.hospitalId = 0,
    this.currentSection,
    this.consultationsPending = 0,
    required this.onLogout,
  });

  const PraticienNav.doctor({
    required this.userName,
    this.userSpecialty,
    this.currentSection,
    this.consultationsPending = 0,
    required this.onLogout,
  })  : isDoctor = true,
        hospitalName = null,
        hospitalId = 0;

  const PraticienNav.hospital({
    required this.userName,
    this.hospitalName,
    this.hospitalId = 0,
    this.currentSection,
    required this.onLogout,
  })  : isDoctor = false,
        userSpecialty = null,
        consultationsPending = 0;
}

/// Écran cible d'une section, ou null si on y est déjà.
Widget? navSectionScreen(PraticienNav nav, NavSection section) {
  if (nav.currentSection == section) return null;
  if (nav.isDoctor) {
    switch (section) {
      case NavSection.dashboard:
        return const DoctorDashboard();
      case NavSection.consultations:
        return const DoctorConsultationsScreen();
      case NavSection.patients:
        return const DoctorPatientsScreen();
      case NavSection.prescriptions:
        return const PrescriptionsScreen();
      case NavSection.messages:
        return const DoctorMessagesScreen();
      case NavSection.profile:
        return ProfileScreen(initialIsDoctor: nav.isDoctor);
      case NavSection.hospitalProfile:
      case NavSection.staff:
      case NavSection.nurseVisits:
      case NavSection.activity:
        return null;
    }
  }
  switch (section) {
    case NavSection.dashboard:
      return const HospitalDashboard();
    case NavSection.hospitalProfile:
      return const HospitalProfileScreen();
    case NavSection.staff:
      return const StaffScreen();
    case NavSection.nurseVisits:
      return NurseVisitsScreen(hospitalId: nav.hospitalId);
    case NavSection.activity:
      return const HospitalActivityScreen();
    case NavSection.profile:
      return ProfileScreen(initialIsDoctor: nav.isDoctor);
    case NavSection.consultations:
    case NavSection.patients:
    case NavSection.prescriptions:
    case NavSection.messages:
      return null;
  }
}

class _NavItemSpec {
  final NavSection section;
  final IconData icon;
  final String label;
  final int Function(PraticienNav nav)? badge;
  const _NavItemSpec(this.section, this.icon, this.label, [this.badge]);
}

final _doctorItems = <_NavItemSpec>[
  _NavItemSpec(NavSection.dashboard, Icons.dashboard_rounded, 'Tableau de bord'),
  _NavItemSpec(NavSection.consultations, Icons.calendar_month_rounded,
      'Consultations', (nav) => nav.consultationsPending),
  _NavItemSpec(NavSection.patients, Icons.people_alt_rounded, 'Patients'),
  _NavItemSpec(NavSection.prescriptions, Icons.receipt_long_rounded, 'Ordonnances'),
  _NavItemSpec(NavSection.messages, Icons.chat_bubble_outline_rounded, 'Messagerie'),
  _NavItemSpec(NavSection.profile, Icons.person_rounded, 'Mon profil'),
];

const _hospitalItems = <_NavItemSpec>[
  _NavItemSpec(NavSection.dashboard, Icons.dashboard_rounded, 'Tableau de bord'),
  _NavItemSpec(NavSection.hospitalProfile, Icons.apartment_rounded, 'Mon hôpital'),
  _NavItemSpec(NavSection.staff, Icons.medical_services_rounded, 'Personnel soignant'),
  _NavItemSpec(NavSection.nurseVisits, Icons.home_repair_service_rounded, 'Soins à domicile'),
  _NavItemSpec(NavSection.activity, Icons.analytics_rounded, 'Activité'),
  _NavItemSpec(NavSection.profile, Icons.person_rounded, 'Profil administrateur'),
];

/// Contenu du menu latéral, partagé entre le sidebar fixe (large écran)
/// et le drawer (petit écran).
class NavPanel extends StatelessWidget {
  final PraticienNav nav;
  final void Function(NavSection section) onNavigate;

  const NavPanel({super.key, required this.nav, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final items = nav.isDoctor ? _doctorItems : _hospitalItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Identité de l'utilisateur connecté
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.primary,
                child: nav.isDoctor
                    ? Text(
                        nav.userName.isNotEmpty
                            ? nav.userName[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      )
                    : const Icon(Icons.apartment_rounded,
                        color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nav.userName.isNotEmpty ? nav.userName : 'Praticien',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            nav.isDoctor
                                ? (nav.userSpecialty?.isNotEmpty == true
                                    ? nav.userSpecialty!
                                    : 'Médecin praticien')
                                : 'Administration d\'établissement',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: Color(0xFF24405F), height: 1, thickness: 1),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final item in items) ...[
                _NavItem(
                  icon: item.icon,
                  label: item.label,
                  isSelected: nav.currentSection == item.section,
                  badge: item.badge?.call(nav) ?? 0,
                  onTap: () => onNavigate(item.section),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        // Déconnexion
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              dense: true,
              leading: const Icon(Icons.logout_rounded,
                  color: Colors.white70, size: 20),
              title: const Text(
                'Déconnexion',
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5),
              ),
              onTap: nav.onLogout,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.22)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primaryLight : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.78),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    borderRadius:
                        BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else if (isSelected)
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
