import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/models/hospital_appointment_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';

class HospitalAppointmentsScreen extends StatefulWidget {
  const HospitalAppointmentsScreen({super.key});

  @override
  State<HospitalAppointmentsScreen> createState() =>
      _HospitalAppointmentsScreenState();
}

class _HospitalAppointmentsScreenState
    extends State<HospitalAppointmentsScreen> {
  UserModel? _user;
  List<HospitalAppointmentModel> _appointments = [];
  Map<String, dynamic> _summary = {};
  List<dynamic> _doctors = [];
  bool _loading = true;
  String? _error;

  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);
  String _selectedDepartment = 'tous';
  String _selectedStatus = 'tous';
  bool _onlyMine = false;

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    final user = await StorageService.getUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      if (user?.isDoctor ?? false) {
        _onlyMine = true;
      }
    });
    _fetchQueue();
  }

  Future<void> _fetchQueue() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.getHospitalQueue(
        date: _selectedDate,
        department: _selectedDepartment == 'tous' ? null : _selectedDepartment,
        status: _selectedStatus == 'tous' ? null : _selectedStatus,
        onlyMine: _onlyMine,
      );

      if (!mounted) return;
      setState(() {
        _appointments = res['appointments'] as List<HospitalAppointmentModel>;
        _summary = res['summary'] as Map<String, dynamic>;
        _doctors = res['doctors'] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _handleLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _handleCheckIn(HospitalAppointmentModel appt) async {
    int? selectedDocId = appt.doctorId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.how_to_reg_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  const Text('Enregistrer l’arrivée', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient : ${appt.patientName}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text('Service : ${appt.department} • Créneau : ${appt.timeSlot}'),
                  const SizedBox(height: 16),
                  const Text('Médecin consultant à affecter :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedDocId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceDim,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    hint: const Text('Premier médecin disponible'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Attribution automatique au premier libre'),
                      ),
                      ..._doctors.map((d) {
                        final id = d['id'] as int;
                        final name = d['name'] as String;
                        final spec = d['specialty'] as String?;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text('$name ${spec != null ? "($spec)" : ""}'),
                        );
                      }),
                    ],
                    onChanged: (val) => setDlgState(() => selectedDocId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Valider & Salle d’attente'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.checkInHospitalAppointment(appt.id, doctorId: selectedDocId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Le patient ${appt.patientName} a été enregistré en salle d’attente.'),
        ),
      );
      _fetchQueue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text('$e')),
      );
    }
  }

  Future<void> _handleCallIn(HospitalAppointmentModel appt) async {
    try {
      await ApiService.callInHospitalAppointment(appt.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0284C7),
          content: Text('Patient ${appt.patientName} invité en consultation.'),
        ),
      );
      _fetchQueue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text('$e')),
      );
    }
  }

  Future<void> _handleComplete(HospitalAppointmentModel appt) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Clôturer la consultation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient : ${appt.patientName}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text('Conclusions médicales ou résumé (facultatif) :', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ex: Traitement prescrit, repos conseillé 3 jours...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.surfaceDim,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer la fin'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.completeHospitalAppointment(appt.id, doctorNotes: notesCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Consultation de ${appt.patientName} clôturée avec succès.'),
        ),
      );
      _fetchQueue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = _user?.isDoctor ?? true;
    final nav = PraticienNav(
      isDoctor: isDoctor,
      userName: _user?.name ?? 'Praticien',
      userSpecialty: _user?.specialty,
      hospitalName: 'Établissement de soins',
      hospitalId: _user?.hospitalId ?? 0,
      currentSection: NavSection.hospitalAppointments,
      onLogout: _handleLogout,
    );

    return ResponsiveShell(
      nav: nav,
      title: isDoctor ? 'Patients sur place & File du jour' : 'Accueil & File d’attente Hôpital',
      onRefresh: _fetchQueue,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _fetchQueue,
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cartes de synthèse du jour
            _buildSummaryRow(),
            const SizedBox(height: 20),

            // Barre de filtres (Date, Département, Statut, Médecin)
            _buildFiltersRow(isDoctor),
            const SizedBox(height: 20),

            // Liste des rendez-vous
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _fetchQueue, child: const Text('Réessayer')),
                    ],
                  ),
                ),
              )
            else if (_appointments.isEmpty)
              _buildEmptyState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _appointments.length,
                itemBuilder: (ctx, idx) => _buildAppointmentCard(_appointments[idx], isDoctor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _buildStatCard(
          label: 'Total attendus',
          value: '${_summary['total_today'] ?? 0}',
          icon: Icons.calendar_today_rounded,
          color: const Color(0xFF64748B),
          bgColor: const Color(0xFFF1F5F9),
        ),
        _buildStatCard(
          label: 'En salle d’attente',
          value: '${_summary['waiting_room'] ?? 0}',
          icon: Icons.airline_seat_recline_normal_rounded,
          color: const Color(0xFF16A34A),
          bgColor: const Color(0xFFDCFCE7),
        ),
        _buildStatCard(
          label: 'En consultation',
          value: '${_summary['in_consultation'] ?? 0}',
          icon: Icons.meeting_room_rounded,
          color: const Color(0xFF0284C7),
          bgColor: const Color(0xFFE0F2FE),
        ),
        _buildStatCard(
          label: 'Consultations finies',
          value: '${_summary['completed'] ?? 0}',
          icon: Icons.check_circle_rounded,
          color: AppColors.primary,
          bgColor: AppColors.primaryLight,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      width: 175,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow(bool isDoctor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Date : $_selectedDate',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_selectedDate) ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked.toIso8601String().substring(0, 10);
                    });
                    _fetchQueue();
                  }
                },
              ),
            ],
          ),

          // Filtre Statut
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip('Tous', 'tous'),
              _buildFilterChip('Salle d’attente', 'en_attente'),
              _buildFilterChip('En consultation', 'en_consultation'),
              _buildFilterChip('Réservés', 'reserve'),
              _buildFilterChip('Terminés', 'termine'),
            ],
          ),

          if (isDoctor)
            FilterChip(
              label: const Text('Mes patients uniquement'),
              selected: _onlyMine,
              onSelected: (val) {
                setState(() => _onlyMine = val);
                _fetchQueue();
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedStatus = value);
        _fetchQueue();
      },
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_available_rounded, size: 54, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Aucune consultation présentielle trouvée pour cette sélection.',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textSecondary),
          ),
          SizedBox(height: 6),
          Text(
            'Les réservations de créneaux sur place effectuées par les patients apparaîtront ici.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(HospitalAppointmentModel appt, bool isDoctor) {
    Color statusBg;
    Color statusColor;
    String statusLabel;

    switch (appt.status) {
      case 'en_attente':
        statusBg = const Color(0xFFDCFCE7);
        statusColor = const Color(0xFF16A34A);
        statusLabel = 'En salle d’attente';
        break;
      case 'en_consultation':
        statusBg = const Color(0xFFE0F2FE);
        statusColor = const Color(0xFF0284C7);
        statusLabel = 'En consultation';
        break;
      case 'termine':
        statusBg = AppColors.surfaceDim;
        statusColor = AppColors.textSecondary;
        statusLabel = 'Clôturée';
        break;
      case 'annule':
        statusBg = const Color(0xFFFEE2E2);
        statusColor = const Color(0xFFDC2626);
        statusLabel = 'Annulée';
        break;
      case 'reserve':
      default:
        statusBg = const Color(0xFFFEF3C7);
        statusColor = const Color(0xFFD97706);
        statusLabel = 'Attendu';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appt.isWaiting
              ? const Color(0xFF16A34A).withValues(alpha: 0.5)
              : (appt.isInConsultation ? const Color(0xFF0284C7) : AppColors.border),
          width: (appt.isWaiting || appt.isInConsultation) ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Badge numéro d'ordre du jour
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '#${appt.queueNumber ?? appt.id}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          appt.patientName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        if (appt.patientBloodGroup != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              appt.patientBloodGroup!,
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Réf : ${appt.referenceCode} • Tél : ${appt.patientPhone ?? "Non renseigné"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Détails du créneau et médecin affecté
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Créneau : ${appt.timeSlot}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_hospital_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Service : ${appt.department}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    appt.doctorName != null
                        ? 'Médecin : ${appt.doctorName} (${appt.doctorSpecialty ?? "Généraliste"})'
                        : 'Médecin : Non affecté (En attente d’attribution)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: appt.doctorName != null ? AppColors.textPrimary : Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (appt.reason != null && appt.reason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Motif : ${appt.reason}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          if (appt.doctorNotes != null && appt.doctorNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Conclusion médecin : ${appt.doctorNotes}',
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Actions interactives selon le rôle et le statut
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              // Bouton Check-in / Accueil (pour l'admin/accueil ou médecin)
              if (appt.isBooked)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleCheckIn(appt),
                  icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                  label: const Text('Valider l’arrivée (Check-in)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),

              // Bouton Appel Patient (pour le médecin)
              if (appt.isWaiting) ...[
                if (!isDoctor)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _handleCheckIn(appt),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Changer de médecin', style: TextStyle(fontSize: 12)),
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleCallIn(appt),
                  icon: const Icon(Icons.door_front_door_rounded, size: 16),
                  label: const Text('Faire entrer le patient', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ],

              // Consultation en cours (Terminer la consultation)
              if (appt.isInConsultation)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleComplete(appt),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Clôturer la consultation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
