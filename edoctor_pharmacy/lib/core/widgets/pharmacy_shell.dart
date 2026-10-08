import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../../data/models/user_model.dart';
import '../../data/models/pharmacy_model.dart';

enum PharmacySection {
  dashboard,
  orders,
  inventory,
  profile,
}

class PharmacyShell extends StatelessWidget {
  final PharmacySection currentSection;
  final String title;
  final Widget child;
  final Widget? floatingActionButton;
  final UserModel? user;
  final PharmacyModel? pharmacy;
  final VoidCallback? onRefresh;

  const PharmacyShell({
    super.key,
    required this.currentSection,
    required this.title,
    required this.child,
    this.floatingActionButton,
    this.user,
    this.pharmacy,
    this.onRefresh,
  });

  void _navigate(BuildContext context, PharmacySection section) {
    if (section == currentSection) return;
    switch (section) {
      case PharmacySection.dashboard:
        Navigator.of(context).pushReplacementNamed('/dashboard');
        break;
      case PharmacySection.orders:
        Navigator.of(context).pushReplacementNamed('/orders');
        break;
      case PharmacySection.inventory:
        Navigator.of(context).pushReplacementNamed('/inventory');
        break;
      case PharmacySection.profile:
        Navigator.of(context).pushReplacementNamed('/profile');
        break;
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous fermer la session de l\'officine ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.outOfStock),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 960;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildSidebar(context),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SelectionArea(
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (pharmacy?.name != null || user?.name != null)
              Text(
                '${pharmacy?.name ?? "Pharmacie"}${user?.name != null && user!.name.isNotEmpty ? " • Titulaire : ${user!.name}" : ""}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              onPressed: onRefresh,
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: child,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentSection.index,
        onDestinationSelected: (idx) => _navigate(context, PharmacySection.values[idx]),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primary),
            label: 'Tableau',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.primary),
            label: 'Stocks',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded, color: AppColors.primary),
            label: 'Officine',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logo & Branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'eDoctor',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        pharmacy?.name ?? 'Pharmacie & Stocks',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      if (user?.name != null && user!.name.isNotEmpty)
                        Text(
                          'Titulaire : ${user!.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Liens de navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _navItem(
                  context,
                  section: PharmacySection.dashboard,
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard_rounded,
                  label: 'Tableau de bord',
                ),
                _navItem(
                  context,
                  section: PharmacySection.orders,
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long_rounded,
                  label: 'Commandes & Ordonnances',
                ),
                _navItem(
                  context,
                  section: PharmacySection.inventory,
                  icon: Icons.inventory_2_outlined,
                  selectedIcon: Icons.inventory_2_rounded,
                  label: 'Gestion des stocks',
                ),
                _navItem(
                  context,
                  section: PharmacySection.profile,
                  icon: Icons.storefront_outlined,
                  selectedIcon: Icons.storefront_rounded,
                  label: 'Fiche Officine',
                ),
              ],
            ),
          ),

          // Carte Officine & Déconnexion
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryContainer,
                  child: const Icon(Icons.medical_services_outlined, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pharmacy?.name ?? user?.name ?? 'Officine',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        user?.email ?? 'Pharmacien',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.textMuted),
                  tooltip: 'Se déconnecter',
                  onPressed: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required PharmacySection section,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = section == currentSection;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13.5,
          ),
        ),
        dense: true,
        onTap: () => _navigate(context, section),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          Row(
            children: [
              if (pharmacy?.name != null || user?.name != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_pharmacy_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        pharmacy?.name ?? 'Officine',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                      if (user?.name != null && user!.name.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Titulaire : ${user!.name}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
              ],
              if (onRefresh != null)
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Actualiser'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
