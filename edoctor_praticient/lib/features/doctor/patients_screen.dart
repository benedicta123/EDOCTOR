import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import 'patient_dossier_screen.dart';

class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final _search = TextEditingController();
  UserModel? _user;
  List<Map<String, dynamic>> _patients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await StorageService.getUser();
      final result = await ApiService.getDoctorPatients(search: _search.text);
      final data = (result['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (mounted) {
        setState(() {
          _user = user;
          _patients = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
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
    return ResponsiveShell(
      title: 'Mes patients',
      subtitle: '${_patients.length} patient(s) suivi(s)',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.doctor(
        userName: _user?.name ?? 'Docteur',
        userSpecialty: _user?.specialty,
        currentSection: NavSection.patients,
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
                TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Rechercher un patient',
                    hintText: 'Nom, e-mail ou téléphone',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Rechercher',
                      onPressed: _load,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (_error != null)
                  EmptyStateCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Chargement impossible',
                    message: _error!,
                  )
                else if (_patients.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.person_search_rounded,
                    title: 'Aucun patient trouvé',
                    message:
                        'Seuls les patients avec qui vous avez eu au moins une consultation apparaissent ici.',
                  )
                else
                  ..._patients.map(_tile),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  Widget _tile(Map<String, dynamic> patient) {
    final name = patient['name'] as String? ?? 'Patient';
    final email = patient['email'] as String? ?? '';
    final consultations = intOrNull(patient['consultations_count']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            email.isEmpty
                ? '$consultations consultation(s) suivie(s)'
                : '$email · $consultations consultation(s)',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.folder_shared_rounded,
            color: AppColors.primary),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PatientDossierScreen(
              patientId: (patient['id'] as num).toInt(),
              patientName: name,
            ),
          ),
        ),
      ),
    );
  }
}
