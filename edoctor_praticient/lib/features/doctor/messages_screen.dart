import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import 'consultation_detail_screen.dart';

class DoctorMessagesScreen extends StatefulWidget {
  const DoctorMessagesScreen({super.key});

  @override
  State<DoctorMessagesScreen> createState() => _DoctorMessagesScreenState();
}

class _DoctorMessagesScreenState extends State<DoctorMessagesScreen> {
  UserModel? _user;
  bool _loading = true;
  List<ConsultationModel> _consultations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await StorageService.getUser();
      final consultations = await ApiService.getConsultations();
      if (mounted) {
        setState(() {
          _user = user;
          _consultations = consultations;
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
      title: 'Messagerie',
      subtitle: 'Échanges cliniques liés à vos consultations',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.doctor(
        userName: _user?.name ?? 'Docteur',
        userSpecialty: _user?.specialty,
        currentSection: NavSection.messages,
        onLogout: _logout,
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          : _consultations.isEmpty
              ? const EmptyStateCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Aucune conversation',
                  message:
                      'Les échanges avec vos patients arrivent ici dès qu’une consultation est acceptée.',
                )
              : Column(
                  children: _consultations.map((consultation) {
                    final live = consultation.status == 'en_cours';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: live
                              ? AppColors.primary.withValues(alpha: 0.45)
                              : AppColors.border,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: live
                              ? AppColors.primaryContainer
                              : AppColors.background,
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: live
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          consultation.patientName.isEmpty
                              ? 'Patient #${consultation.patientId}'
                              : consultation.patientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Consultation ${consultation.displayCode} · ${formatDateTime(consultation.scheduledAt)}',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusChip(status: consultation.status),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.textMuted),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConsultationDetailScreen(
                              consultation: consultation,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
