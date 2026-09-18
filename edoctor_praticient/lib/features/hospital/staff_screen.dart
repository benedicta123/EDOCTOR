import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';

/// GET /my-hospital/staff + POST /my-hospital/doctors|nurses
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  UserModel? _user;
  List<UserModel> _doctors = [];
  List<UserModel> _nurses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = await StorageService.getUser();
      final staff = await ApiService.getHospitalStaff();
      List<UserModel> parse(String key) =>
          ((staff[key] as List?) ?? [])
              .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
              .toList();
      if (mounted) {
        setState(() {
          _user = user;
          _doctors = parse('doctors');
          _nurses = parse('nurses');
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showMsg(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
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

  void _openForm(bool isDoctor) {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final phone = TextEditingController();
    final specialty = TextEditingController();
    final license = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                isDoctor
                    ? Icons.medical_services_outlined
                    : Icons.medication_outlined,
                size: 19,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                isDoctor ? 'Ajouter un médecin' : 'Ajouter un infirmier',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Nom complet')),
              const SizedBox(height: 12),
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail')),
              const SizedBox(height: 12),
              TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Mot de passe (8 caractères minimum)')),
              const SizedBox(height: 12),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Téléphone')),
              if (isDoctor) ...[
                const SizedBox(height: 12),
                TextField(
                    controller: specialty,
                    decoration: const InputDecoration(
                        labelText: 'Spécialité *',
                        hintText: 'ex. Cardiologie')),
              ],
              const SizedBox(height: 12),
              TextField(
                  controller: license,
                  decoration: const InputDecoration(
                      labelText: 'N° licence / ordre *')),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              try {
                if (isDoctor) {
                  await ApiService.createDoctor(
                    name: name.text.trim(),
                    email: email.text.trim(),
                    password: password.text,
                    phone: phone.text.trim(),
                    specialty: specialty.text.trim(),
                    licenseNumber: license.text.trim(),
                  );
                } else {
                  await ApiService.createNurse(
                    name: name.text.trim(),
                    email: email.text.trim(),
                    password: password.text,
                    phone: phone.text.trim(),
                    licenseNumber: license.text.trim(),
                  );
                }
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                if (mounted) {
                  showMsg(context, 'Personnel soignant ajouté avec succès');
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  showMsg(
                      context,
                      e.toString().replaceFirst('Exception: ', ''),
                      error: true);
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      title: 'Personnel soignant',
      subtitle:
          '${_doctors.length} médecin(s) · ${_nurses.length} infirmier(s)',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.hospital(
        userName: _user?.name ?? 'Administrateur',
        hospitalId: _user?.hospitalId ?? 0,
        currentSection: NavSection.staff,
        onLogout: _logout,
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.primaryHover,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13.5),
                    tabs: [
                      Tab(text: 'Médecins (${_doctors.length})'),
                      Tab(text: 'Infirmiers (${_nurses.length})'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 540,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _list(_doctors, true),
                      _list(_nurses, false),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _list(List<UserModel> users, bool isDoctor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _openForm(isDoctor),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(
                isDoctor ? 'Ajouter un médecin' : 'Ajouter un infirmier'),
          ),
          const SizedBox(height: 14),
          if (users.isEmpty)
            EmptyStateCard(
              icon: isDoctor
                  ? Icons.medical_services_outlined
                  : Icons.medication_outlined,
              title: isDoctor
                  ? 'Aucun médecin enregistré'
                  : 'Aucun infirmier enregistré',
              message:
                  'Cliquez sur le bouton ci-dessus pour créer le compte du premier membre de votre personnel.',
            )
          else
            ...users.map(
              (u) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ),
                  title: Text(
                    isDoctor ? doctorDisplay(u.name) : u.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${u.email}${u.specialty != null && u.specialty!.isNotEmpty ? ' · ${u.specialty}' : ''}',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5),
                        ),
                        if (u.licenseNumber != null &&
                            u.licenseNumber!.isNotEmpty)
                          Text(
                            'Licence : ${u.licenseNumber}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  isThreeLine: u.licenseNumber != null,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
