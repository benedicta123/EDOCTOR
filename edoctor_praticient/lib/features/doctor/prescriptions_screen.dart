import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/prescription_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});
  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  UserModel? _user;
  List<PrescriptionModel> _items = [];
  bool _loading = true;
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await StorageService.getUser();
      final list = await ApiService.getPrescriptions();
      if (mounted) {
        setState(() {
          _user = user;
          _items = list;
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

  Future<void> _cancel(int id) async {
    try {
      await ApiService.cancelPrescription(id);
      if (mounted) showMsg(context, 'Ordonnance annulée');
      _load();
    } catch (e) {
      if (mounted) {
        showMsg(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      title: 'Ordonnances',
      subtitle: '${_items.length} prescription(s) enregistrée(s)',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.doctor(
        userName: _user?.name ?? 'Docteur',
        userSpecialty: _user?.specialty,
        currentSection: NavSection.prescriptions,
        onLogout: _logout,
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          : _items.isEmpty
              ? const EmptyStateCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucune ordonnance',
                  message:
                      'Rédigez une ordonnance depuis la fiche d’une consultation en cours : medicaments, posologies et quantités.',
                )
              : Column(
                  children: _items.map((p) {
                    final expanded = _expandedId == p.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          initiallyExpanded: expanded,
                          onExpansionChanged: (v) =>
                              setState(() => _expandedId = v ? p.id : null),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.receipt_long_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          title: Text(
                            p.patientName.isEmpty
                                ? 'Ordonnance #${p.id}'
                                : 'Ordonnance #${p.id} · ${p.patientName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${p.items.length} médicament(s)',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5),
                            ),
                          ),
                          trailing: StatusChip(status: p.status),
                          children: [
                            ...p.items.map(
                              (it) => Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.medication_rounded,
                                        size: 18, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            it.medicationName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${it.dosageInstructions} · quantité ${it.quantity}',
                                            style: const TextStyle(
                                                color: AppColors
                                                    .textSecondary,
                                                fontSize: 12.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (p.homeCareRecommended)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.home_outlined,
                                        size: 16, color: AppColors.primary),
                                    SizedBox(width: 6),
                                    Text(
                                      'Soins à domicile recommandés',
                                      style: TextStyle(
                                          color: AppColors.primaryHover,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            if (p.status == 'validee') ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: BorderSide(
                                        color:
                                            AppColors.error.withValues(alpha: 0.4)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => _cancel(p.id),
                                  icon: const Icon(Icons.cancel_outlined,
                                      size: 18),
                                  label: const Text('Annuler l’ordonnance'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
