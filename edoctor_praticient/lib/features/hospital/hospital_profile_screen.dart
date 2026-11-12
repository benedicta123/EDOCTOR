import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/hospital_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import 'staff_screen.dart';
import 'nurse_visits_screen.dart';

class HospitalProfileScreen extends StatefulWidget {
  const HospitalProfileScreen({super.key});

  @override
  State<HospitalProfileScreen> createState() => _HospitalProfileScreenState();
}

class _HospitalProfileScreenState extends State<HospitalProfileScreen> {
  UserModel? _user;
  HospitalModel? _hospital;
  bool _loading = true;
  bool _uploadingDocument = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final hospital = await ApiService.getMyHospital();
      if (mounted) {
        setState(() {
          _user = user;
          _hospital = hospital;
          _loading = false;
        });
      }
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

  Future<void> _uploadLicenseDocument() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (picked == null) return;
      final sizeBytes = picked.lengthSync() ?? await picked.length();
      if (sizeBytes != null && sizeBytes > 10 * 1024 * 1024) {
        if (mounted) {
          showMsg(
            context,
            'Le fichier dépasse la limite autorisée de 10 Mo.',
            error: true,
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() => _uploadingDocument = true);
      await ApiService.uploadHospitalLicenseDocument(picked);
      if (!mounted) return;
      showMsg(context, "Pièce d'agrément transmise avec succès.");
      await _load();
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingDocument = false);
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
    final hospital = _hospital;
    final user = _user;

    return ResponsiveShell(
      title: 'Mon hôpital',
      subtitle: 'Fiche officielle et accréditations sanitaires',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.hospital(
        userName: user?.name ?? 'Administrateur',
        hospitalName: hospital?.name,
        hospitalId: hospital?.id ?? user?.hospitalId ?? 0,
        currentSection: NavSection.hospitalProfile,
        onLogout: _logout,
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          : hospital == null
              ? const EmptyStateCard(
                  icon: Icons.apartment_rounded,
                  title: 'Établissement indisponible',
                  message:
                      'Les informations sur votre établissement n’ont pas pu être chargées. Vérifiez la connexion à l’API puis réessayez.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHospitalHeader(hospital),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _statPill(
                            'Médecins affiliés',
                            '${hospital.doctors.length}',
                            Icons.medical_services_outlined,
                            AppColors.primary,
                            AppColors.primaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statPill(
                            'Infirmiers soignants',
                            '${hospital.nurses.length}',
                            Icons.medication_outlined,
                            AppColors.secondary,
                            AppColors.secondaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      icon: Icons.contact_mail_outlined,
                      title: 'Coordonnées & accès',
                      children: [
                        Wrap(
                          spacing: 34,
                          runSpacing: 16,
                          children: [
                            InfoTile('Adresse complète', hospital.address,
                                Icons.location_on_outlined),
                            InfoTile('Téléphone officiel', hospital.phone,
                                Icons.phone_outlined),
                            InfoTile('E-mail officiel', hospital.officialEmail,
                                Icons.email_outlined),
                            InfoTile(
                              'Coordonnées GPS',
                              '${hospital.latitude ?? '—'}, ${hospital.longitude ?? '—'}',
                              Icons.my_location_rounded,
                            ),
                            InfoTile(
                              'Tarif consultation',
                              '${hospital.consultationFee.toInt()} FCFA',
                              Icons.payments_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _sectionCard(
                      icon: Icons.verified_user_outlined,
                      title: 'Conformité & accréditation eDoctor',
                      children: [
                        Wrap(
                          spacing: 34,
                          runSpacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            InfoTile('Numéro de licence', hospital.licenseNumber,
                                Icons.badge_outlined),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Statut d’accréditation eDoctor',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                StatusChip(status: hospital.status),
                              ],
                            ),
                            InfoTile(
                              'Date de vérification',
                              formatDateTime(hospital.verifiedAt),
                              Icons.event_available_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _HospitalLicenseDocumentBox(
                          documentPath: hospital.licenseDocumentPath,
                          uploading: _uploadingDocument,
                          onUpload: _uploadLicenseDocument,
                        ),
                        if (hospital.status == 'en_attente') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.hourglass_top_rounded,
                                    size: 18, color: AppColors.warning),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Votre dossier est en cours d’examen par l’équipe eDoctor. Vous recevrez une notification dès validation.',
                                    style: TextStyle(
                                        color: AppColors.warning,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
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
                                  builder: (_) => const StaffScreen()),
                            ),
                            icon: const Icon(Icons.people_alt_outlined),
                            label: const Text('Gérer le personnel'),
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
                                builder: (_) =>
                                    NurseVisitsScreen(hospitalId: hospital.id),
                              ),
                            ),
                            icon: const Icon(Icons.home_repair_service_outlined),
                            label: const Text('Visites à domicile'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
    );
  }

  Widget _buildHospitalHeader(HospitalModel hospital) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.apartment_rounded,
                color: Colors.white, size: 34),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hospital.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusChip(status: hospital.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Établissement hospitalier partenaire eDoctor · ID #${hospital.id}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.white38),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hospital.address ?? 'Adresse non renseignée',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
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
    );
  }

  Widget _statPill(String label, String value, IconData icon, Color color,
      Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
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
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _HospitalLicenseDocumentBox extends StatelessWidget {
  const _HospitalLicenseDocumentBox({
    required this.documentPath,
    required this.uploading,
    required this.onUpload,
  });

  final String? documentPath;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final raw = documentPath?.trim() ?? '';
    final hasDoc = raw.isNotEmpty;
    final fileName = hasDoc ? raw.split('/').last : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasDoc ? AppColors.successLight : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDoc
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: hasDoc
                      ? AppColors.success.withValues(alpha: 0.14)
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasDoc
                      ? Icons.description_outlined
                      : Icons.upload_file_rounded,
                  size: 18,
                  color: hasDoc ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasDoc
                        ? 'Justificatif transmis : $fileName'
                        : 'Aucune pièce justificative transmise',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Format accepté : Document PDF uniquement (max 10 Mo)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: uploading ? null : onUpload,
            icon: uploading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    hasDoc
                        ? Icons.sync_rounded
                        : Icons.cloud_upload_outlined,
                    size: 16,
                  ),
            label: Text(
              uploading
                  ? 'Envoi...'
                  : hasDoc
                  ? 'Mettre à jour la pièce'
                  : 'Téléverser l\'agrément',
            ),
          ),
        ],
      ),
    );
  }
}
