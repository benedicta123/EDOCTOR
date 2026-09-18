import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/nurse_visit_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';

/// GET /hospitals/{id}/nurse-visits + POST /nurse-visits/{id}/assign
class NurseVisitsScreen extends StatefulWidget {
  final int hospitalId;
  const NurseVisitsScreen({super.key, required this.hospitalId});
  @override
  State<NurseVisitsScreen> createState() => _NurseVisitsScreenState();
}

class _NurseVisitsScreenState extends State<NurseVisitsScreen> {
  UserModel? _user;
  List<NurseVisitModel> _visits = [];
  List<UserModel> _nurses = [];
  bool _loading = true;
  String _filter = 'toutes';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await StorageService.getUser();
      final visits = await ApiService.getNurseVisits(widget.hospitalId);
      List<UserModel> nurses = [];
      try {
        final staff = await ApiService.getHospitalStaff();
        nurses = ((staff['nurses'] as List?) ?? [])
            .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _user = user;
          _visits = visits;
          _nurses = nurses;
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

  List<NurseVisitModel> get _filtered {
    if (_filter == 'toutes') return _visits;
    return _visits.where((v) => v.status == _filter).toList();
  }

  int _countOf(String status) =>
      _visits.where((v) => v.status == status).length;

  void _assign(NurseVisitModel v) {
    int? selected;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Affecter la visite #${v.id}'),
        content: _nurses.isEmpty
            ? const Text(
                'Aucun infirmier disponible dans votre établissement. Ajoutez-en d’abord via « Personnel soignant ».')
            : DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                    labelText: 'Sélectionner un infirmier'),
                items: _nurses
                    .map((n) =>
                        DropdownMenuItem(value: n.id, child: Text(n.name)))
                    .toList(),
                onChanged: (x) => selected = x,
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
              if (selected == null && _nurses.isNotEmpty) return;
              if (_nurses.isEmpty) {
                Navigator.pop(dialogCtx);
                return;
              }
              try {
                await ApiService.assignNurseVisit(v.id, selected!);
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                if (mounted) {
                  showMsg(context, 'Infirmier affecté à la visite avec succès');
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
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = <String, String>{
      'toutes': 'Toutes',
      'en_attente': 'En attente',
      'assignee': 'Assignées',
      'terminee': 'Terminées',
    };

    return ResponsiveShell(
      title: 'Soins à domicile',
      subtitle:
          '${_visits.length} demande(s) de visite · ${_countOf('en_attente')} en attente d’affectation',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.hospital(
        userName: _user?.name ?? 'Administrateur',
        hospitalId: widget.hospitalId,
        currentSection: NavSection.nurseVisits,
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
                  spacing: 8,
                  runSpacing: 8,
                  children: chips.entries.map((entry) {
                    final count = entry.key == 'toutes'
                        ? _visits.length
                        : _countOf(entry.key);
                    return ChoiceChip(
                      label: Text('${entry.value} ($count)'),
                      selected: _filter == entry.key,
                      onSelected: (_) =>
                          setState(() => _filter = entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (_filtered.isEmpty)
                  EmptyStateCard(
                    icon: Icons.home_repair_service_outlined,
                    title: 'Aucune visite à domicile',
                    message:
                        'Aucune demande ne correspond au filtre « ${chips[_filter]} » pour le moment.',
                  )
                else
                  ..._filtered.map((v) {
                    final isPending = v.status == 'en_attente';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPending
                              ? AppColors.warning.withValues(alpha: 0.45)
                              : AppColors.border,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: isPending
                              ? AppColors.warningLight
                              : AppColors.primaryContainer,
                          child: Icon(
                            Icons.home_outlined,
                            color: isPending
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          v.patientName.isEmpty
                              ? 'Patient #${v.patientId}'
                              : v.patientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visite #${v.id} · Prescription #${v.prescriptionId}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Infirmier : ${v.nurseName.isEmpty ? 'Non affecté' : v.nurseName}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isPending
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                                  fontWeight: isPending
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            StatusChip(status: v.status),
                          ],
                        ),
                        onTap:
                            isPending ? () => _assign(v) : null,
                      ),
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}
