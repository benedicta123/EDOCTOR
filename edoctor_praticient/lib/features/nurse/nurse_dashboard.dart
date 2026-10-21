import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/nurse_visit_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';

/// Tableau de bord mobile pour Infirmier(e) à domicile.
/// Permet de consulter ses tournées du jour, de se mettre en route
/// et de saisir les constantes vitales & actes au chevet du patient.
class NurseDashboard extends StatefulWidget {
  const NurseDashboard({super.key});

  @override
  State<NurseDashboard> createState() => _NurseDashboardState();
}

class _NurseDashboardState extends State<NurseDashboard>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  List<NurseVisitModel> _visits = [];
  bool _loading = true;
  bool _updatingStatus = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final visits = await ApiService.getMyNurseVisits();
      if (!mounted) return;
      setState(() {
        _user = user;
        _visits = visits;
        _loading = false;
      });
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

  Future<void> _changeAvailability(String status) async {
    setState(() => _updatingStatus = true);
    try {
      await ApiService.updateDoctorAvailability(status);
      final user = await StorageService.getUser();
      if (user != null) {
        final updated = UserModel(
          id: user.id,
          name: user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          licenseNumber: user.licenseNumber,
          specialty: user.specialty,
          availabilityStatus: status,
          hospitalId: user.hospitalId,
          dateOfBirth: user.dateOfBirth,
          address: user.address,
        );
        await StorageService.saveUser(updated);
        if (mounted) setState(() => _user = updated);
      }
      if (mounted) {
        final label = status == 'en_mission'
            ? 'En mission / intervention'
            : status == 'disponible'
                ? 'Disponible'
                : 'Indisponible';
        showMsg(context, 'Statut infirmier mis à jour : $label');
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
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _acceptVisit(NurseVisitModel visit) async {
    try {
      await ApiService.acceptNurseVisit(visit.id);
      if (mounted) {
        showMsg(context, 'Mission démarrée ! Vous êtes en route vers le patient.');
        _load();
      }
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  Future<void> _declineVisit(NurseVisitModel visit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Décliner cette mission ?'),
        content: const Text(
          'La visite sera renvoyée à l\'hôpital pour réaffectation à un autre confrère disponible.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, décliner'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ApiService.declineNurseVisit(visit.id);
      if (mounted) {
        showMsg(context, 'Mission déclinée.');
        _load();
      }
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  Future<void> _openCompleteSheet(NurseVisitModel visit) async {
    final bpCtrl = TextEditingController(text: visit.bloodPressure ?? '');
    final bgCtrl = TextEditingController(text: visit.bloodGlucose ?? '');
    final tempCtrl = TextEditingController(text: visit.temperature ?? '');
    final hrCtrl = TextEditingController(text: visit.heartRate ?? '');
    final reportCtrl = TextEditingController(text: visit.report ?? '');

    final availableActs = [
      'Pansement stérile',
      'Injection intramusculaire (IM)',
      'Injection sous-cutanée (SC)',
      'Perfusion & surveillance',
      'Prise de constantes vitales',
      'Soins de sonde / stomie',
      'Soins d\'hygiène & confort',
    ];

    final selectedActs = <String>{...visit.actsPerformed};
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fiche de soins & constantes',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Patient : ${visit.patientName}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Actes de soins réalisés :',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableActs.map((act) {
                    final isChecked = selectedActs.contains(act);
                    return FilterChip(
                      label: Text(act),
                      selected: isChecked,
                      selectedColor: AppColors.primaryContainer,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isChecked ? FontWeight.w700 : FontWeight.w500,
                        color: isChecked
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                      onSelected: (selected) {
                        setSheetState(() {
                          if (selected) {
                            selectedActs.add(act);
                          } else {
                            selectedActs.remove(act);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Constantes vitales au chevet du patient :',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: bpCtrl,
                        decoration: InputDecoration(
                          labelText: 'Tension (ex: 12/8)',
                          labelStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.favorite_rounded,
                              size: 18, color: Color(0xFFEF4444)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: bgCtrl,
                        decoration: InputDecoration(
                          labelText: 'Glycémie (ex: 1.05 g/L)',
                          labelStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.water_drop_rounded,
                              size: 18, color: Color(0xFF3B82F6)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: tempCtrl,
                        decoration: InputDecoration(
                          labelText: 'Température (ex: 37.2 °C)',
                          labelStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.thermostat_rounded,
                              size: 18, color: Color(0xFFF59E0B)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: hrCtrl,
                        decoration: InputDecoration(
                          labelText: 'Pouls (ex: 74 bpm)',
                          labelStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.monitor_heart_rounded,
                              size: 18, color: Color(0xFF10B981)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reportCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Observations & transmissions infirmières',
                    alignLabelWithHint: true,
                    hintText:
                        'Évolution de la plaie, tolérance aux médicaments, conseils donnés au patient...',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      saving
                          ? 'Enregistrement…'
                          : 'Valider les soins & clôturer la visite',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            try {
                              await ApiService.completeNurseVisit(
                                visit.id,
                                report: reportCtrl.text.trim(),
                                bloodPressure: bpCtrl.text.trim(),
                                bloodGlucose: bgCtrl.text.trim(),
                                temperature: tempCtrl.text.trim(),
                                heartRate: hrCtrl.text.trim(),
                                actsPerformed: selectedActs.toList(),
                              );
                              if (!mounted) return;
                              Navigator.of(ctx).pop();
                              showMsg(context,
                                  'Soins validés ! Les constantes ont été enregistrées dans le dossier médical.');
                              _load();
                            } catch (e) {
                              setSheetState(() => saving = false);
                              if (!mounted) return;
                              showMsg(
                                context,
                                e
                                    .toString()
                                    .replaceFirst('Exception: ', ''),
                                error: true,
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeVisits =
        _visits.where((v) => v.isAssigned || v.isEnRoute).toList();
    final completedVisits = _visits.where((v) => v.isCompleted).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _user?.name.isNotEmpty == true
                  ? 'Inf. ${_user!.name}'
                  : 'Espace Infirmier',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const Text(
              'Soins à domicile & Tournées',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.directions_bike_rounded, size: 20),
              text: 'À faire (${activeVisits.length})',
            ),
            Tab(
              icon: const Icon(Icons.done_all_rounded, size: 20),
              text: 'Historique (${completedVisits.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildNurseStatusCard(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.72,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildVisitsList(activeVisits, isActive: true),
                        _buildVisitsList(completedVisits, isActive: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNurseStatusCard() {
    final status = _user?.availabilityStatus ?? 'disponible';
    final isEnMission = status == 'en_mission';
    final isDispo = status == 'disponible';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isDispo
                      ? AppColors.success
                      : isEnMission
                          ? AppColors.primary
                          : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isDispo
                    ? 'Disponible pour nouvelles missions'
                    : isEnMission
                        ? 'En mission / intervention à domicile'
                        : 'Indisponible',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_updatingStatus) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDispo
                        ? AppColors.success.withValues(alpha: 0.1)
                        : Colors.transparent,
                    side: BorderSide(
                      color: isDispo ? AppColors.success : AppColors.border,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isDispo
                      ? null
                      : () => _changeAvailability('disponible'),
                  child: const Text('Disponible',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !isDispo && !isEnMission
                        ? Colors.grey.withValues(alpha: 0.1)
                        : Colors.transparent,
                    side: BorderSide(
                      color: !isDispo && !isEnMission
                          ? Colors.grey
                          : AppColors.border,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: (!isDispo && !isEnMission)
                      ? null
                      : () => _changeAvailability('indisponible'),
                  child: const Text('Indisponible',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisitsList(List<NurseVisitModel> visits,
      {required bool isActive}) {
    if (visits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive
                    ? Icons.assignment_turned_in_rounded
                    : Icons.history_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                isActive
                    ? 'Aucune mission en attente'
                    : 'Aucun historique de soins',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isActive
                    ? 'Dès que l\'hôpital vous affecte une visite à domicile, elle s\'affichera ici.'
                    : 'Les comptes-rendus de vos soins terminés apparaîtront ici.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: visits.length,
      itemBuilder: (ctx, idx) => _buildVisitCard(visits[idx]),
    );
  }

  Widget _buildVisitCard(NurseVisitModel visit) {
    Color badgeColor;
    IconData badgeIcon;

    if (visit.isCompleted) {
      badgeColor = AppColors.success;
      badgeIcon = Icons.check_circle_rounded;
    } else if (visit.isEnRoute) {
      badgeColor = AppColors.primary;
      badgeIcon = Icons.directions_bike_rounded;
    } else {
      badgeColor = AppColors.warning;
      badgeIcon = Icons.assignment_ind_rounded;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 13, color: badgeColor),
                      const SizedBox(width: 5),
                      Text(
                        visit.statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Prescription #${visit.prescriptionId}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    visit.patientName.isNotEmpty
                        ? visit.patientName[0].toUpperCase()
                        : 'P',
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
                        visit.patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (visit.patientBirthDate.isNotEmpty)
                        Text(
                          'Né(e) le : ${visit.patientBirthDate}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (visit.doctorName.isNotEmpty)
                        Text(
                          'Prescrit par le Dr. ${visit.doctorName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Contact & Adresse
            if (visit.patientAddress.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        visit.patientAddress,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copier l\'adresse',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: visit.patientAddress));
                        showMsg(context, 'Adresse copiée dans le presse-papier');
                      },
                    ),
                  ],
                ),
              ),
            if (visit.patientPhone.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    visit.patientPhone,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Copier le numéro',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: visit.patientPhone));
                      showMsg(context, 'Numéro copié');
                    },
                  ),
                ],
              ),
            // Constantes déjà relevées si terminée
            if (visit.isCompleted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Constantes & Soins enregistrés :',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (visit.bloodPressure != null)
                          _vitalBadge('Tension', visit.bloodPressure!),
                        if (visit.bloodGlucose != null)
                          _vitalBadge('Glycémie', visit.bloodGlucose!),
                        if (visit.temperature != null)
                          _vitalBadge('Température', visit.temperature!),
                        if (visit.heartRate != null)
                          _vitalBadge('Pouls', visit.heartRate!),
                      ],
                    ),
                    if (visit.actsPerformed.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Actes : ${visit.actsPerformed.join(', ')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (visit.report != null && visit.report!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Notes : ${visit.report}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            // Boutons d'action dynamique
            if (visit.isAssigned) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _declineVisit(visit),
                      child: const Text('Décliner',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.directions_bike_rounded, size: 16),
                      label: const Text(
                        'En route chez le patient',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => _acceptVisit(visit),
                    ),
                  ),
                ],
              ),
            ] else if (visit.isEnRoute) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.medical_services_rounded, size: 18),
                  label: const Text(
                    'Réaliser les soins & saisir les constantes',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => _openCompleteSheet(visit),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _vitalBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$label : $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
