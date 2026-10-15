import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../../data/models/user_model.dart';
import '../../features/auth/login_screen.dart';

enum AdminSection {
  overview,
  hospitals,
  pharmacies,
  users,
  claims,
}

class AdminShell extends StatefulWidget {
  final AdminSection currentSection;
  final String title;
  final String? subtitle;
  final Widget child;
  final UserModel? user;
  final VoidCallback? onRefresh;
  final List<Widget>? actions;

  const AdminShell({
    super.key,
    required this.currentSection,
    required this.title,
    this.subtitle,
    required this.child,
    this.user,
    this.onRefresh,
    this.actions,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  UserModel? _currentUser;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser == null) {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    final u = await StorageService.getUser();
    if (mounted) setState(() => _currentUser = u);
  }

  void _navigateTo(AdminSection section) {
    if (section == widget.currentSection) return;
    Navigator.pushReplacementNamed(context, '/${section.name}');
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion Super-Admin'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter de la console de régulation ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rejected, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loggingOut = true);
      await ApiService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar de navigation régalienne
          Container(
            width: 270,
            decoration: const BoxDecoration(
              color: AppColors.sidebarBg,
              border: Border(right: BorderSide(color: AppColors.sidebarBorder, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Logo officiel eDoctor
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo_blanc.png',
                            height: 36,
                            errorBuilder: (_, _, _) => const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 32),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SUPER-ADMIN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Opérations, Conformité & Accréditation',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(color: AppColors.sidebarBorder, height: 1),

                // Éléments du Menu
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    children: [
                      _buildNavSectionHeader('PILOTAGE & SUPERVISION'),
                      _buildNavItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Vue d\'ensemble Réseau',
                        section: AdminSection.overview,
                      ),
                      const SizedBox(height: 16),

                      _buildNavSectionHeader('CONFORMITÉ ÉTABLISSEMENTS'),
                      _buildNavItem(
                        icon: Icons.local_hospital_rounded,
                        label: 'Hôpitaux Partenaires',
                        section: AdminSection.hospitals,
                      ),
                      _buildNavItem(
                        icon: Icons.local_pharmacy_rounded,
                        label: 'Pharmacies & Officines',
                        section: AdminSection.pharmacies,
                      ),
                      const SizedBox(height: 16),

                      _buildNavSectionHeader('MODÉRATION & LITIGES'),
                      _buildNavItem(
                        icon: Icons.people_alt_rounded,
                        label: 'Gestion Utilisateurs',
                        section: AdminSection.users,
                      ),
                      _buildNavItem(
                        icon: Icons.report_problem_rounded,
                        label: 'Journal des Réclamations',
                        section: AdminSection.claims,
                      ),
                    ],
                  ),
                ),

                const Divider(color: AppColors.sidebarBorder, height: 1),

                // Profil Super-Admin & Déconnexion
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sidebarSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sidebarBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.shield_rounded, size: 20, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentUser?.name ?? 'Super-Administrateur',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Équipe Opérations & Accréditation',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF5EEAD4),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: _loggingOut
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.logout_rounded, size: 18, color: AppColors.textMuted),
                          onPressed: _loggingOut ? null : _logout,
                          tooltip: 'Déconnexion',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Zone Principale
          Expanded(
            child: Column(
              children: [
                // TopBar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          // Badge statut plateforme en ligne
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.verifiedBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.verifiedBorder),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 8,
                                  height: 8,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.verified),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Plateforme eDoctor Opérationnelle',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.verified),
                                ),
                              ],
                            ),
                          ),
                          if (widget.onRefresh != null) ...[
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
                              onPressed: widget.onRefresh,
                              tooltip: 'Actualiser les données',
                            ),
                          ],
                          if (widget.actions != null) ...[
                            const SizedBox(width: 8),
                            ...widget.actions!,
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Contenu de la page
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required AdminSection section,
  }) {
    final isActive = widget.currentSection == section;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateTo(section),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? AppColors.sidebarActive : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Colors.white : const Color(0xFFCBD5E1),
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
}
