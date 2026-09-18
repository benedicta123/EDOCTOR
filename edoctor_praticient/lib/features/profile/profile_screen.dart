import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import '../hospital/hospital_profile_screen.dart';

/// Profil du praticien (médecin ou admin d'hôpital) :
/// identité, informations professionnelles, disponibilité, session.
class ProfileScreen extends StatefulWidget {
  final bool initialIsDoctor;
  const ProfileScreen({super.key, this.initialIsDoctor = true});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  bool _heartbeatLoading = false;
  bool _availabilityLoading = false;
  int _activeTabIndex = 0;

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _specialty;
  late final TextEditingController _license;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _specialty = TextEditingController();
    _license = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _specialty.dispose();
    _license.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final fresh = await ApiService.me();
      if (mounted) {
        setState(() {
          _user = fresh;
          _loading = false;
        });
        _fillControllers(fresh);
        await StorageService.saveSession(
          token: (await StorageService.getToken()) ?? '',
          user: fresh,
        );
      }
    } catch (_) {
      final local = await StorageService.getUser();
      if (mounted) {
        setState(() {
          _user = local;
          _loading = false;
        });
        if (local != null) _fillControllers(local);
      }
    }
  }

  void _fillControllers(UserModel user) {
    _name.text = user.name;
    _phone.text = user.phone ?? '';
    _specialty.text = user.specialty ?? '';
    _license.text = user.licenseNumber ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final fields = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
      };
      if (_user?.isDoctor == true) {
        fields['specialty'] = _specialty.text.trim();
        fields['license_number'] = _license.text.trim();
      }
      final updated = await ApiService.updateProfile(fields);
      await StorageService.saveSession(
        token: (await StorageService.getToken()) ?? '',
        user: updated,
      );
      if (mounted) {
        setState(() {
          _user = updated;
          _editing = false;
        });
        showMsg(context, 'Profil mis à jour avec succès');
      }
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAvailability(String status) async {
    setState(() => _availabilityLoading = true);
    try {
      await ApiService.updateDoctorAvailability(status);
      await _load();
      if (mounted) {
        showMsg(context, 'Disponibilité mise à jour : ${_availabilityLabel(status)}');
      }
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _availabilityLoading = false);
    }
  }

  String _availabilityLabel(String s) {
    switch (s) {
      case 'disponible':
        return 'Disponible';
      case 'indisponible':
        return 'Indisponible';
      case 'en_consultation':
        return 'En consultation';
      default:
        return s;
    }
  }

  Future<void> _sendHeartbeat() async {
    setState(() => _heartbeatLoading = true);
    try {
      await ApiService.heartbeat();
      if (mounted) {
        showMsg(context, 'Présence transmise — vous êtes marqué en ligne.');
      }
    } catch (e) {
      if (mounted) {
        showMsg(context, 'Impossible d’actualiser la présence.', error: true);
      }
    } finally {
      if (mounted) setState(() => _heartbeatLoading = false);
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
    final user = _user;
    final isDoctor = user?.isDoctor ?? widget.initialIsDoctor;

    return ResponsiveShell(
      title: 'Mon profil',
      subtitle: isDoctor
          ? 'Espace praticien · informations et disponibilité'
          : 'Administration d’établissement',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav(
        isDoctor: isDoctor,
        userName: user?.name ?? (isDoctor ? 'Docteur' : 'Administrateur'),
        userSpecialty: user?.specialty,
        hospitalName: user?.name,
        hospitalId: user?.hospitalId ?? 0,
        currentSection: NavSection.profile,
        onLogout: _logout,
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          : user == null
              ? const EmptyStateCard(
                  icon: Icons.person_off_rounded,
                  title: 'Profil inaccessible',
                  message:
                      'Vos informations n’ont pas pu être chargées. Reconnectez-vous puis réessayez.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildIdentityHeader(user),
                    const SizedBox(height: 18),
                    if (_editing)
                      _buildEditPanel(isDoctor)
                    else ...[
                      _buildTabSelector(isDoctor),
                      const SizedBox(height: 16),
                      _buildActiveTabContent(user, isDoctor),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
    );
  }

  // ── En-tête d'identité ─────────────────────────────────────────────

  Widget _buildIdentityHeader(UserModel user) {
    final isDoctor = user.isDoctor;
    final availability = user.availabilityStatus;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1E30), AppColors.secondary, Color(0xFF1A3558)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.primaryLight, width: 2),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDoctor ? doctorDisplay(user.name) : user.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  size: 12, color: AppColors.primaryLight),
                              const SizedBox(width: 5),
                              Text(
                                isDoctor
                                    ? 'Médecin certifié'
                                    : 'Administrateur',
                                style: const TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isDoctor && availability != null &&
                            availability.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _availabilityBadge(availability),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Modifier mes informations',
                onPressed: () => setState(() {
                  _editing = true;
                  _fillControllers(user);
                }),
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
              color: Colors.white.withValues(alpha: 0.1),
              height: 1,
              thickness: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _contactChip(Icons.email_outlined, user.email),
              if (user.phone?.isNotEmpty == true)
                _contactChip(Icons.phone_outlined, user.phone!),
              if (isDoctor &&
                  user.licenseNumber?.isNotEmpty == true)
                _contactChip(Icons.verified_outlined,
                    'N° ${user.licenseNumber!}'),
              if (!isDoctor)
                _contactChip(Icons.apartment_outlined,
                    'Établissement #${user.hospitalId ?? 1}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _availabilityBadge(String status) {
    final color = status == 'disponible'
        ? AppColors.success
        : status == 'en_consultation'
            ? AppColors.primaryLight
            : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status == 'disponible'
              ? Icons.check_circle_rounded
              : status == 'en_consultation'
                  ? Icons.sensors_rounded
                  : Icons.do_not_disturb_on_rounded, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            _availabilityLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Sélecteur d'onglets ────────────────────────────────────────────

  Widget _buildTabSelector(bool isDoctor) {
    final tabs = isDoctor
        ? [
            const _TabSpec(Icons.badge_outlined, 'Informations'),
            const _TabSpec(Icons.wifi_tethering_rounded, 'Disponibilité'),
            const _TabSpec(Icons.security_rounded, 'Sécurité'),
          ]
        : [
            const _TabSpec(Icons.badge_outlined, 'Informations'),
            const _TabSpec(Icons.apartment_rounded, 'Établissement'),
            const _TabSpec(Icons.security_rounded, 'Sécurité'),
          ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final item = tabs[index];
          final selected = _activeTabIndex == index;
          return Expanded(
            child: Material(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  _editing = false;
                  _activeTabIndex = index;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 16,
                        color: selected
                            ? AppColors.primaryHover
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                            color: selected
                                ? AppColors.primaryHover
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveTabContent(UserModel user, bool isDoctor) {
    switch (_activeTabIndex) {
      case 0:
        return _buildGeneralTab(user, isDoctor);
      case 1:
        return isDoctor
            ? _buildDoctorPresenceTab(user)
            : _buildHospitalAffiliationTab(user);
      case 2:
        return _buildSecurityTab(user);
      default:
        return _buildGeneralTab(user, isDoctor);
    }
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? caption,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: AppColors.textPrimary),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  // ── Onglet 1 : informations ────────────────────────────────────────

  Widget _buildGeneralTab(UserModel user, bool isDoctor) {
    return _sectionCard(
      icon: Icons.badge_outlined,
      title: 'Informations professionnelles',
      caption: 'Ces données sont visibles par vos patients et votre établissement.',
      children: [
        Wrap(
          spacing: 34,
          runSpacing: 20,
          children: [
            InfoTile('Nom complet', user.name, Icons.person_outline),
            InfoTile('Adresse e-mail', user.email, Icons.email_outlined),
            InfoTile('Téléphone', user.phone, Icons.phone_outlined),
            InfoTile(
                'Rôle clinique',
                isDoctor ? 'Médecin traitant' : 'Administrateur d’établissement',
                Icons.work_outline),
            if (isDoctor) ...[
              InfoTile('Spécialité médicale', user.specialty,
                  Icons.medical_services_outlined),
              InfoTile('Numéro d’ordre / Licence', user.licenseNumber,
                  Icons.verified_outlined),
              InfoTile(
                  'Hôpital de rattachement',
                  user.hospitalId != null
                      ? 'Établissement #${user.hospitalId}'
                      : 'Cabinet privé / non rattaché',
                  Icons.apartment_outlined),
            ] else
              InfoTile('Établissement géré', 'Hôpital #${user.hospitalId ?? 1}',
                  Icons.apartment_outlined),
          ],
        ),
      ],
    );
  }

  // ── Onglet 2 : présence (docteur) / établissement (admin) ─────────

  Widget _buildDoctorPresenceTab(UserModel user) {
    final availability = user.availabilityStatus ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          icon: Icons.wifi_tethering_rounded,
          title: 'Disponibilité clinique',
          caption:
              'Votre statut est visible par les patients lors de la prise de rendez-vous.',
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _availabilityOption(
                  value: 'disponible',
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Disponible',
                  selected: availability == 'disponible',
                ),
                _availabilityOption(
                  value: 'en_consultation',
                  icon: Icons.sensors_rounded,
                  label: 'En consultation',
                  selected: availability == 'en_consultation',
                ),
                _availabilityOption(
                  value: 'indisponible',
                  icon: Icons.do_not_disturb_on_outlined,
                  label: 'Indisponible',
                  selected: availability == 'indisponible',
                ),
              ],
            ),
            if (_availabilityLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Présence temps réel',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      SizedBox(height: 3),
                      Text(
                        'Un signal est envoyé automatiquement toutes les 45 secondes tant que cette page reste ouverte.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _heartbeatLoading ? null : _sendHeartbeat,
                  child: _heartbeatLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Signaler maintenant'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _availabilityOption({
    required String value,
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _availabilityLoading || selected
            ? null
            : () => _setAvailability(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryHover
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalAffiliationTab(UserModel user) {
    return _sectionCard(
      icon: Icons.apartment_rounded,
      title: 'Établissement sous gestion',
      caption: 'Fiche officielle de l’hôpital, effectifs soignants et coordonnées.',
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_hospital_rounded,
                  color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Établissement #${user.hospitalId ?? 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Consultez la fiche complète : coordonnées, agrément et personnel.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const HospitalProfileScreen()),
          ),
          icon: const Icon(Icons.apartment_rounded, size: 18),
          label: const Text('Consulter la fiche de l’hôpital'),
        ),
      ],
    );
  }

  // ── Onglet 3 : sécurité ────────────────────────────────────────────

  Widget _buildSecurityTab(UserModel user) {
    return _sectionCard(
      icon: Icons.security_rounded,
      title: 'Sécurité & session',
      caption: 'Authentification et contrôle de votre session eDoctor.',
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: AppColors.success, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Session sécurisée active',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    'Connecté en tant que ${user.email} · jeton Sanctum actif',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        SizedBox(
          width: 240,
          child: CustomButton(
            label: 'Se déconnecter',
            onPressed: _logout,
          ),
        ),
      ],
    );
  }

  // ── Panneau d'édition ──────────────────────────────────────────────

  Widget _buildEditPanel(bool isDoctor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Modifier mes informations',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                tooltip: 'Annuler',
                onPressed: () => setState(() {
                  _editing = false;
                  if (_user != null) _fillControllers(_user!);
                }),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
          ),
          if (isDoctor) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _specialty,
              decoration: const InputDecoration(
                labelText: 'Spécialité médicale',
                hintText: 'ex. Cardiologie, Médecine générale',
                prefixIcon: Icon(Icons.medical_services_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _license,
              decoration: const InputDecoration(
                labelText: 'Numéro d’ordre / Licence',
                prefixIcon: Icon(Icons.verified_user_outlined, size: 20),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _editing = false;
                    if (_user != null) _fillControllers(_user!);
                  }),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  label: 'Enregistrer',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabSpec {
  final IconData icon;
  final String label;
  const _TabSpec(this.icon, this.label);
}
