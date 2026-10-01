import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';

class HospitalActivityScreen extends StatefulWidget {
  const HospitalActivityScreen({super.key});

  @override
  State<HospitalActivityScreen> createState() => _HospitalActivityScreenState();
}

class _HospitalActivityScreenState extends State<HospitalActivityScreen> {
  UserModel? _user;
  List<ConsultationModel> _consultations = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        ApiService.getHospitalConsultations(
          status: _filter.isEmpty ? null : _filter,
        ),
        ApiService.getHospitalStatistics(),
      ]);
      final consultationData = responses[0];
      final rows = (consultationData['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((row) => ConsultationModel.fromJson(row))
          .toList();
      final user = await StorageService.getUser();
      if (mounted) {
        setState(() {
          _user = user;
          _consultations = rows;
          _stats = responses[1];
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
      title: 'Activité de l’hôpital',
      subtitle: 'Consultations et indicateurs de votre établissement',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.hospital(
        userName: _user?.name ?? 'Administrateur',
        hospitalId: _user?.hospitalId ?? 0,
        currentSection: NavSection.activity,
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
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatCard(
                      icon: Icons.calendar_month_rounded,
                      label: 'Consultations',
                      value: intOrNull(_stats['consultations_total']),
                      color: AppColors.primary,
                    ),
                    StatCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Terminées',
                      value: intOrNull(_stats['consultations_completed']),
                      color: AppColors.secondary,
                    ),
                    StatCard(
                      icon: Icons.people_alt_rounded,
                      label: 'Patients',
                      value: intOrNull(_stats['unique_patients']),
                      color: AppColors.primaryHover,
                    ),
                    StatCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'Ordonnances',
                      value: intOrNull(_stats['prescriptions_total']),
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                SectionHeader(title: 'Détail des consultations'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    {'value': '', 'label': 'Toutes'},
                    {'value': 'en_attente', 'label': 'En attente'},
                    {'value': 'en_cours', 'label': 'En cours'},
                    {'value': 'terminee', 'label': 'Terminées'},
                    {'value': 'annulee', 'label': 'Annulées'},
                  ]
                      .map(
                        (f) => ChoiceChip(
                          label: Text(f['label']!),
                          selected: _filter == f['value'],
                          onSelected: (_) {
                            setState(() => _filter = f['value']!);
                            _load();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                if (_consultations.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.event_busy_rounded,
                    title: 'Aucune consultation',
                    message:
                        'Aucune consultation ne correspond à ce filtre pour votre établissement.',
                  )
                else
                  ..._consultations.map(
                    (consultation) => Container(
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
                          backgroundColor: AppColors.background,
                          child: Text(
                            consultation.patientName.isNotEmpty
                                ? consultation.patientName[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
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
                            [
                              if (consultation.doctorName.isNotEmpty)
                                doctorDisplay(consultation.doctorName),
                              'Consultation ${consultation.displayCode}',
                            ].join(' · '),
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5),
                          ),
                        ),
                        trailing: StatusChip(status: consultation.status),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}
