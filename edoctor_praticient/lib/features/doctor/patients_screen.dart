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
    final patientId = (patient['id'] as num?)?.toInt() ?? 0;
    final name = patient['name'] as String? ?? 'Patient';
    final email = (patient['email'] as String? ?? '').trim();
    final phone = (patient['phone'] as String? ?? '').trim();
    final quartier = (patient['address'] as String? ??
            patient['neighborhood'] as String? ??
            patient['quartier'] as String? ??
            '')
        .trim();
    final consultations = intOrNull(patient['consultations_count']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PatientDossierScreen(
                patientId: patientId,
                patientName: name,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête : Avatar, Nom complet, Bouton d'accès dossier
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Patient eDoctor',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            AppColors.secondaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_shared_rounded,
                              size: 15, color: AppColors.secondary),
                          SizedBox(width: 6),
                          Text(
                            'Dossier',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(
                    height: 1, thickness: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),

                // ── Informations du patient : Téléphone, Email, Quartier ──
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    // Téléphone
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          phone.isNotEmpty ? phone : 'Tél : Non renseigné',
                          style: TextStyle(
                            fontSize: 13,
                            color: phone.isNotEmpty
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // Email
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          email.isNotEmpty ? email : 'Email : Non renseigné',
                          style: TextStyle(
                            fontSize: 13,
                            color: email.isNotEmpty
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Quartier
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          quartier.isNotEmpty
                              ? 'Quartier : $quartier'
                              : 'Quartier : Non renseigné',
                          style: TextStyle(
                            fontSize: 13,
                            color: quartier.isNotEmpty
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Nombre de consultations avec ce médecin ──
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.medical_services_outlined,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          consultations > 1
                              ? '$consultations consultations réalisées avec vous'
                              : (consultations == 1
                                  ? '1 consultation réalisée avec vous'
                                  : 'Aucune consultation terminée avec vous'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: AppColors.primary),
                    ],
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
