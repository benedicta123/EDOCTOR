import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/patient_bottom_nav.dart';
import '../auth/register_step1_screen.dart';
import '../claims/claims_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  final ValueChanged<int>? onNavSelected;

  const PatientProfileScreen({super.key, this.onNavSelected});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final int _currentNavIndex = 3;
  bool _notificationsEnabled = true;
  bool _smsRemindersEnabled = true;

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
            Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text(
              'Mon Profil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // Carte Avatar & Nom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryContainer,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bénédicta Mensah',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'benedictehounkanli@gmail.com',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Compte Patient Vérifié',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Section Informations du compte
            _buildSectionContainer(
              title: 'Informations personnelles',
              children: [
                _buildProfileItem(
                  icon: Icons.phone_outlined,
                  title: 'Numéro de téléphone',
                  value: '+228 96469693',
                ),
                _buildDivider(),
                _buildProfileItem(
                  icon: Icons.cake_outlined,
                  title: 'Date de naissance',
                  value: '20 Mars 2005 (21 ans)',
                ),
                _buildDivider(),
                _buildProfileItem(
                  icon: Icons.location_on_outlined,
                  title: 'Adresse de résidence',
                  value: 'AVEPOZO, Lomé, Togo',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Section Partenaires & Établissements
            _buildSectionContainer(
              title: 'Établissements & Praticiens',
              children: [
                _buildProfileItem(
                  icon: Icons.local_hospital_outlined,
                  title: 'Hôpital de rattachement',
                  value: 'Centre Hospitalier Universitaire de Démo',
                ),
                _buildDivider(),
                _buildProfileItem(
                  icon: Icons.local_pharmacy_outlined,
                  title: 'Pharmacie favorite',
                  value: 'Grande Pharmacie Centrale de Démo',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Section Préférences & Notifications
            _buildSectionContainer(
              title: 'Notifications & Alertes',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _notificationsEnabled,
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Rappels de prise de médicaments',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    'Alertes automatiques selon vos ordonnances',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onChanged: (val) {
                    setState(() => _notificationsEnabled = val);
                  },
                ),
                _buildDivider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _smsRemindersEnabled,
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Suivi de commande par SMS',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    'Statut de préparation et de livraison en pharmacie',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onChanged: (val) {
                    setState(() => _smsRemindersEnabled = val);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Section Aide & Numéros d'urgence
            _buildSectionContainer(
              title: 'Assistance & Urgences',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.emergency_rounded, color: AppColors.error, size: 20),
                  ),
                  title: const Text(
                    'Urgences Médicales (SAMU / Pompiers)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  subtitle: const Text('Appel immédiat d\'urgence au 118 / 15', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.call_rounded, color: AppColors.error, size: 20),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Appel des urgences médicales (118)...'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  },
                ),
                _buildDivider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: const Text(
                    'Assistance & Réclamations',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  subtitle: const Text('Litiges, suivi des réclamations & support 7j/7', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ClaimsScreen()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Bouton Déconnexion
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                label: const Text(
                  'Se déconnecter',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: PatientBottomNav(
        currentIndex: _currentNavIndex,
        onTabSelected: (index) {
          if (widget.onNavSelected != null) {
            widget.onNavSelected!(index);
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: AppColors.borderLight),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter de votre compte eDoctor ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Se déconnecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await StorageService.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RegisterStep1Screen()),
        (route) => false,
      );
    }
  }
}
