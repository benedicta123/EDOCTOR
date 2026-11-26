import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../data/models/hospital_appointment_model.dart';

String _fmtApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmtShort(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtFr(DateTime d, {bool withWeekday = true}) {
  const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  const months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];
  final m = months[d.month - 1];
  if (!withWeekday) return '${d.day} $m ${d.year}';
  return '${days[d.weekday - 1]} ${d.day} $m ${d.year}';
}

class HospitalAppointmentsScreen extends StatefulWidget {
  const HospitalAppointmentsScreen({super.key});

  @override
  State<HospitalAppointmentsScreen> createState() => _HospitalAppointmentsScreenState();
}

class _HospitalAppointmentsScreenState extends State<HospitalAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<HospitalAppointmentModel> _myAppointments = [];
  bool _loadingAppointments = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyAppointments() async {
    setState(() => _loadingAppointments = true);
    try {
      final raw = await ApiService.getMyHospitalAppointments();
      setState(() {
        _myAppointments = raw.map(HospitalAppointmentModel.fromJson).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAppointments = false);
    }
  }

  Future<void> _cancelAppointment(HospitalAppointmentModel apt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: Text(
            'Annuler votre créneau du ${_fmtShort(apt.appointmentDate)} (${apt.timeSlot}) à ${apt.hospital?.name ?? 'l\'hôpital'} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Annuler le RDV'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.cancelHospitalAppointment(apt.id);
      await _loadMyAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation annulée.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Réservations Hôpital', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Mes réservations'),
            Tab(text: 'Prendre RDV'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyAppointmentsTab(),
          _buildBookingTab(),
        ],
      ),
    );
  }

  // ─── Onglet "Mes réservations" ─────────────────────────────────────────────

  Widget _buildMyAppointmentsTab() {
    if (_loadingAppointments) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_myAppointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined, size: 80, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Aucune réservation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Prenez un RDV à l\'hôpital depuis l\'onglet\n"Prendre RDV".',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.add),
              label: const Text('Prendre un RDV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    final active = _myAppointments.where((a) => a.isActive).toList();
    final past = _myAppointments.where((a) => a.isDone).toList();

    return RefreshIndicator(
      onRefresh: _loadMyAppointments,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (active.isNotEmpty) ...[
            const Text('En cours', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...active.map((a) => _buildAppointmentCard(a)),
            const SizedBox(height: 20),
          ],
          if (past.isNotEmpty) ...[
            const Text('Historique', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...past.map((a) => _buildAppointmentCard(a)),
          ],
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(HospitalAppointmentModel apt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    apt.hospital?.name ?? 'Hôpital',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: apt.statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: apt.statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(apt.statusLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: apt.statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.local_hospital_outlined, apt.department),
            const SizedBox(height: 4),
            _infoRow(Icons.calendar_today_outlined, _fmtFr(apt.appointmentDate)),
            const SizedBox(height: 4),
            _infoRow(Icons.access_time_outlined, apt.timeSlot),
            const SizedBox(height: 4),
            _infoRow(Icons.confirmation_number_outlined, 'N° passage : #${apt.queueNumber}  •  Réf : ${apt.referenceCode}'),
            if (apt.doctor != null) ...[
              const SizedBox(height: 4),
              _infoRow(Icons.person_outline_rounded, 'Dr. ${apt.doctor!.name}${apt.doctor!.specialty != null ? ' — ${apt.doctor!.specialty}' : ''}'),
            ],
            if (apt.reason != null && apt.reason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _infoRow(Icons.notes_outlined, apt.reason!),
            ],
            if (apt.isCancellable) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancelAppointment(apt),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Annuler'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      ],
    );
  }

  // ─── Onglet "Prendre RDV" ─────────────────────────────────────────────────

  Widget _buildBookingTab() {
    return _BookingFlow(onBooked: () {
      _tabController.animateTo(0);
      _loadMyAppointments();
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOKING FLOW — Stepper multi-étapes
// ═══════════════════════════════════════════════════════════════════════════

class _BookingFlow extends StatefulWidget {
  final VoidCallback onBooked;
  const _BookingFlow({required this.onBooked});

  @override
  State<_BookingFlow> createState() => _BookingFlowState();
}

class _BookingFlowState extends State<_BookingFlow> {
  int _step = 0; // 0=hôpital 1=département/date 2=créneau 3=confirmation

  // Données de l'API
  List<Map<String, dynamic>> _hospitals = [];
  List<String> _departments = [];
  List<AppointmentDoctorModel> _doctors = [];
  List<SlotModel> _slots = [];
  bool _loading = false;

  // Sélections du patient
  Map<String, dynamic>? _selectedHospital;
  String? _selectedDepartment;
  DateTime _selectedDate = DateTime.now();
  SlotModel? _selectedSlot;
  AppointmentDoctorModel? _selectedDoctor;
  String _reason = '';
  bool _byDoctor = false;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getHospitals();
      setState(() => _hospitals = list);
    } catch (_) {
      // Si l'endpoint /hospitals n'existe pas encore, on propose une saisie manuelle
      setState(() => _hospitals = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSlots() async {
    if (_selectedHospital == null) return;
    setState(() => _loading = true);
    try {
      final hospitalId = (_selectedHospital!['id'] as num).toInt();
      final dateStr = _fmtApi(_selectedDate);
      final data = await ApiService.getHospitalSlots(
        hospitalId,
        date: dateStr,
        department: _selectedDepartment,
      );
      setState(() {
        _departments = (data['departments'] as List? ?? []).cast<String>();
        _doctors = (data['doctors'] as List? ?? [])
            .map((d) => AppointmentDoctorModel.fromJson(d as Map<String, dynamic>))
            .toList();
        _slots = (data['slots'] as List? ?? [])
            .map((s) => SlotModel.fromJson(s as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    if (_selectedHospital == null || _selectedDepartment == null || _selectedSlot == null) return;
    setState(() => _loading = true);
    try {
      await ApiService.bookHospitalAppointment(
        hospitalId: (_selectedHospital!['id'] as num).toInt(),
        department: _selectedDepartment!,
        appointmentDate: _fmtApi(_selectedDate),
        timeSlot: _selectedSlot!.timeSlot,
        doctorId: _selectedDoctor?.id,
        reason: _reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Votre créneau a été réservé !'), backgroundColor: AppColors.success),
        );
        widget.onBooked();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Indicateur d'étapes
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: List.generate(4, (i) {
              final isActive = i == _step;
              final isDone = i < _step;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.success : (isActive ? AppColors.primary : AppColors.border),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text('${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? Colors.white : AppColors.textMuted,
                                )),
                      ),
                    ),
                    if (i < 3)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: i < _step ? AppColors.success : AppColors.border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildStep(),
                ),
        ),
      ],
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildStepHospital();
      case 1:
        return _buildStepDeptDate();
      case 2:
        return _buildStepSlot();
      case 3:
        return _buildStepConfirm();
      default:
        return const SizedBox();
    }
  }

  // Étape 1 — Choisir l'hôpital
  Widget _buildStepHospital() {
    if (_hospitals.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Choisir un hôpital'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE08A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aucun hôpital disponible pour le moment. Contactez votre administrateur pour activer la réservation.',
                    style: TextStyle(fontSize: 13, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Choisir un hôpital'),
        const SizedBox(height: 4),
        const Text('Sélectionnez l\'établissement de santé de votre choix.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        ..._hospitals.map((h) {
          final isSelected = _selectedHospital?['id'] == h['id'];
          return GestureDetector(
            onTap: () => setState(() {
              _selectedHospital = h;
              _selectedDepartment = null;
              _selectedSlot = null;
              _selectedDoctor = null;
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryContainer : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.local_hospital_rounded,
                        color: isSelected ? Colors.white : AppColors.textMuted, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h['name'] as String? ?? 'Hôpital',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                        if (h['address'] != null)
                          Text(h['address'] as String,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        _nextButton('Continuer', _selectedHospital != null ? () async {
          await _loadSlots();
          if (mounted) setState(() => _step = 1);
        } : null),
      ],
    );
  }

  // Étape 2 — Département + Date
  Widget _buildStepDeptDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Service & Date'),
        const SizedBox(height: 4),
        Text('Choisissez le service souhaité et la date de visite.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 20),

        // Choix du mode (par service ou par médecin)
        const Text('Mode de réservation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _modeButton('Par service médical', !_byDoctor, Icons.medical_services_outlined, () {
              setState(() { _byDoctor = false; _selectedDoctor = null; });
            })),
            const SizedBox(width: 10),
            Expanded(child: _modeButton('Par médecin', _byDoctor, Icons.person_search_outlined, () {
              setState(() => _byDoctor = true);
            })),
          ],
        ),

        const SizedBox(height: 20),
        const Text('Service médical *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDepartment,
              hint: const Text('Sélectionner un service'),
              isExpanded: true,
              items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() { _selectedDepartment = v; _selectedSlot = null; }),
            ),
          ),
        ),

        if (_byDoctor && _doctors.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Médecin (facultatif)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AppointmentDoctorModel>(
                value: _selectedDoctor,
                hint: const Text('Choisir un médecin'),
                isExpanded: true,
                items: _doctors
                    .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text('Dr. ${d.name}${d.specialty != null ? ' (${d.specialty})' : ''}')))
                    .toList(),
                onChanged: (v) => setState(() => _selectedDoctor = v),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),
        const Text('Date souhaitée *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderFocus),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primaryContainer,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  _fmtFr(_selectedDate),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                const Spacer(),
                const Icon(Icons.edit_calendar_outlined, size: 16, color: AppColors.primary),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Row(
          children: [
            _backButton(),
            const SizedBox(width: 12),
            Expanded(
              child: _nextButton('Voir les créneaux', _selectedDepartment != null ? () async {
                await _loadSlots();
                if (mounted) setState(() => _step = 2);
              } : null),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      locale: const Locale('fr'),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _selectedDate = picked; _selectedSlot = null; });
  }

  Widget _modeButton(String label, bool selected, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted, size: 24),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            )),
          ],
        ),
      ),
    );
  }

  // Étape 3 — Choisir le créneau horaire
  Widget _buildStepSlot() {
    final available = _slots.where((s) => s.available).toList();
    final full = _slots.where((s) => !s.available).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Choisir un créneau'),
        Text(
          '${_fmtFr(_selectedDate, withWeekday: false)} — ${_selectedDepartment ?? ''}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        if (available.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.event_busy_outlined, color: AppColors.error),
                SizedBox(width: 10),
                Expanded(child: Text('Aucun créneau disponible pour cette date.\nChoisissez une autre date.', style: TextStyle(color: AppColors.error))),
              ],
            ),
          ),

        if (available.isNotEmpty) ...[
          const Text('Créneaux disponibles', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: available.map((s) {
              final isSelected = _selectedSlot?.timeSlot == s.timeSlot;
              return GestureDetector(
                onTap: () => setState(() => _selectedSlot = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
                  ),
                  child: Column(
                    children: [
                      Text(s.timeSlot, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      )),
                      Text('${s.remaining} pl. restante${s.remaining > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : AppColors.textMuted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        if (full.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Créneaux complets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: full.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(s.timeSlot, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, decoration: TextDecoration.lineThrough)),
            )).toList(),
          ),
        ],

        const SizedBox(height: 24),
        Row(
          children: [
            _backButton(),
            const SizedBox(width: 12),
            Expanded(
              child: _nextButton('Confirmer', _selectedSlot != null ? () => setState(() => _step = 3) : null),
            ),
          ],
        ),
      ],
    );
  }

  // Étape 4 — Confirmation
  Widget _buildStepConfirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Confirmer la réservation'),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow(Icons.local_hospital_rounded, 'Établissement', _selectedHospital?['name'] as String? ?? '—'),
              const Divider(height: 20),
              _summaryRow(Icons.medical_services_outlined, 'Service', _selectedDepartment ?? '—'),
              const Divider(height: 20),
              _summaryRow(Icons.calendar_today_outlined, 'Date', _fmtFr(_selectedDate)),
              const Divider(height: 20),
              _summaryRow(Icons.access_time_outlined, 'Créneau', _selectedSlot?.timeSlot ?? '—'),
              if (_selectedDoctor != null) ...[
                const Divider(height: 20),
                _summaryRow(Icons.person_outline_rounded, 'Médecin', 'Dr. ${_selectedDoctor!.name}'),
              ],
              const Divider(height: 20),
              _summaryRow(Icons.payments_outlined, 'Frais de consultation',
                  '${num.tryParse(_selectedHospital?['consultation_fee']?.toString() ?? '')?.toInt() ?? 3000} FCFA'),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text('Motif de consultation (facultatif)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Ex : Douleurs abdominales, bilan annuel…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
            filled: true,
            fillColor: AppColors.surface,
          ),
          maxLines: 3,
          onChanged: (v) => _reason = v,
        ),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(10)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Un numéro de passage vous sera attribué. Présentez votre code de référence à l\'accueil.',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Row(
          children: [
            _backButton(),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _book,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirmer la réservation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
        ),
      ],
    );
  }

  Widget _stepTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    );
  }

  Widget _nextButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  Widget _backButton() {
    return OutlinedButton(
      onPressed: () => setState(() => _step--),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(80, 52),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
    );
  }
}
