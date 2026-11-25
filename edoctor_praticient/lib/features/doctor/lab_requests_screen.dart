import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/url_opener_helper.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/lab_request_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import 'widgets/lab_requests_view.dart';

/// Écran dédié aux bilans d'analyses et résultats transmis par les patients.
class LabRequestsScreen extends StatefulWidget {
  const LabRequestsScreen({super.key});

  @override
  State<LabRequestsScreen> createState() => _LabRequestsScreenState();
}

class _LabRequestsScreenState extends State<LabRequestsScreen> {
  UserModel? _user;
  List<LabRequestModel> _items = [];
  bool _loading = true;
  String _filter = 'tous';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final list = await ApiService.getMyLabRequests();
      if (!mounted) return;
      setState(() {
        _user = user;
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMsg(context, e.toString().replaceFirst('Exception: ', ''), error: true);
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

  List<LabRequestModel> get _filteredItems {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _items.where((lab) {
      if (_filter == 'resultats_recus' && lab.status != 'resultats_recus') {
        return false;
      }
      if (_filter == 'en_attente' &&
          lab.status != 'prescrit' &&
          lab.status != 'en_attente_resultats') {
        return false;
      }
      if (_filter == 'analyse_terminee' && lab.status != 'analyse_terminee') {
        return false;
      }
      if (q.isNotEmpty) {
        final matchPatient = lab.patientName.toLowerCase().contains(q);
        final matchRef = lab.referenceCode.toLowerCase().contains(q);
        final matchExam = lab.items.any((it) => it.name.toLowerCase().contains(q));
        if (!matchPatient && !matchRef && !matchExam) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final receivedCount =
        _items.where((l) => l.status == 'resultats_recus').length;
    final filtered = _filteredItems;

    return ResponsiveShell(
      title: 'Analyses & Résultats',
      subtitle: 'Bilans prescrits et documents transmis par vos patients',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.doctor(
        userName: _user?.name ?? 'Médecin',
        userSpecialty: _user?.specialty,
        currentSection: NavSection.labRequests,
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
                // Barre de recherche et filtres
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'Rechercher par patient, référence (LAB-...) ou examen...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChipBtn(
                            label: 'Tous (${_items.length})',
                            selected: _filter == 'tous',
                            onTap: () => setState(() => _filter = 'tous'),
                          ),
                          _FilterChipBtn(
                            label: 'Résultats reçus ($receivedCount)',
                            selected: _filter == 'resultats_recus',
                            highlight: receivedCount > 0,
                            onTap: () =>
                                setState(() => _filter = 'resultats_recus'),
                          ),
                          _FilterChipBtn(
                            label: 'En attente',
                            selected: _filter == 'en_attente',
                            onTap: () => setState(() => _filter = 'en_attente'),
                          ),
                          _FilterChipBtn(
                            label: 'Analysés & validés',
                            selected: _filter == 'analyse_terminee',
                            onTap: () =>
                                setState(() => _filter = 'analyse_terminee'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.biotech_rounded,
                    title: 'Aucun bilan d’analyse trouvé',
                    message:
                        'Les bilans prescrits et les résultats transmis par vos patients apparaîtront ici.',
                  )
                else
                  ...filtered.map((lab) => _LabCard(
                        lab: lab,
                        onRefresh: _load,
                      )),
              ],
            ),
    );
  }
}

class _FilterChipBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;

  const _FilterChipBtn({
    required this.label,
    required this.selected,
    this.highlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg =
        highlight ? const Color(0xFF0284C7) : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeBg : AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeBg
                : (highlight ? const Color(0xFF0284C7) : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (highlight ? const Color(0xFF0284C7) : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _LabCard extends StatelessWidget {
  final LabRequestModel lab;
  final VoidCallback onRefresh;

  const _LabCard({required this.lab, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    Color statusBg;
    Color statusColor;
    switch (lab.status) {
      case 'resultats_recus':
        statusBg = const Color(0xFFE0F2FE);
        statusColor = const Color(0xFF0284C7);
        break;
      case 'analyse_terminee':
        statusBg = AppColors.successLight;
        statusColor = AppColors.success;
        break;
      default:
        statusBg = AppColors.warningLight;
        statusColor = AppColors.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: lab.status == 'resultats_recus'
              ? const Color(0xFF0284C7).withValues(alpha: 0.5)
              : AppColors.border,
          width: lab.status == 'resultats_recus' ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lab.referenceCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lab.patientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Prescrit le ${lab.formattedDate}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lab.statusDisplayLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Examens demandés
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: lab.items.map((it) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.science_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      it.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          // Résultats transmis par le patient
          if (lab.hasResults) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.attach_file_rounded,
                    size: 17, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Text(
                  'Résultats transmis (${lab.results.length} document${lab.results.length > 1 ? 's' : ''})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: lab.results.map((res) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => showLabResultViewer(context, res),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              res.isImage
                                  ? Icons.image_rounded
                                  : Icons.picture_as_pdf_rounded,
                              size: 22,
                              color: const Color(0xFF0284C7),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  res.fileName,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0C4A6E),
                                  ),
                                ),
                                Text(
                                  'Cliquer pour visualiser · ${res.formattedDate}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0369A1),
                                  ),
                                ),
                                if (res.patientNotes != null &&
                                    res.patientNotes!.isNotEmpty)
                                  Text(
                                    'Note : ${res.patientNotes}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (res.filePath.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Ouvrir dans un nouvel onglet',
                          icon: const Icon(Icons.open_in_new_rounded,
                              size: 18, color: Color(0xFF0284C7)),
                          onPressed: () =>
                              UrlOpenerHelper.openInNewTab(res.filePath),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          if (lab.doctorReviewNotes != null &&
              lab.doctorReviewNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Votre conclusion : ${lab.doctorReviewNotes}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],

          if (lab.hasResults && lab.status != 'analyse_terminee') ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => showLabReviewDialog(
                  context,
                  labRequest: lab,
                  onSuccess: onRefresh,
                ),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text(
                  'Examiner & Valider le bilan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
