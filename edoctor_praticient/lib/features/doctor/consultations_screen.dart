import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/incoming_call_watcher.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import 'widgets/consultation_card.dart';

class DoctorConsultationsScreen extends StatefulWidget {
  const DoctorConsultationsScreen({super.key});

  @override
  State<DoctorConsultationsScreen> createState() =>
      _DoctorConsultationsScreenState();
}

class _DoctorConsultationsScreenState extends State<DoctorConsultationsScreen> {
  UserModel? _user;
  List<ConsultationModel> _consultations = [];
  bool _loading = true;
  String _filter = 'toutes';
  Timer? _autoRefresh;
  int? _actingId;

  static const _filters = <String, String>{
    'toutes': 'Toutes',
    'en_attente': 'En attente',
    'en_cours': 'En cours',
    'terminee': 'Terminées',
    'annulee': 'Annulées',
  };

  @override
  void initState() {
    super.initState();
    _load();
    IncomingCallWatcher.instance.start();
    _autoRefresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  int _compareConsultations(ConsultationModel a, ConsultationModel b) {
    int priority(String s) {
      if (s == 'en_cours') return 0;
      if (s == 'en_attente') return 1;
      return 2;
    }

    final pa = priority(a.status);
    final pb = priority(b.status);
    if (pa != pb) return pa.compareTo(pb);
    return (b.createdAt ?? '').compareTo(a.createdAt ?? '');
  }

  Future<void> _silentRefresh() async {
    try {
      final consultations = await ApiService.getConsultations();
      if (!mounted) return;
      consultations.sort(_compareConsultations);
      setState(() => _consultations = consultations);
    } catch (_) {}
  }

  Future<void> _accept(ConsultationModel c) async {
    IncomingCallWatcher.instance.markHandled(c.id);
    setState(() => _actingId = c.id);
    try {
      await ApiService.consultationAction(c.id, 'start');
      if (!mounted) return;
      showMsg(context, 'Consultation ${c.displayCode} acceptée — en cours');
      await _silentRefresh();
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _decline(ConsultationModel c) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => DeclineDialog(patientName: c.patientName),
    );
    if (reason == null) return;

    IncomingCallWatcher.instance.markHandled(c.id);
    setState(() => _actingId = c.id);
    try {
      await ApiService.consultationAction(c.id, 'decline', reason: reason);
      if (!mounted) return;
      showMsg(context, 'Consultation ${c.displayCode} refusée. Le patient a été notifié.');
      await _silentRefresh();
    } catch (e) {
      if (mounted) {
        showMsg(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await StorageService.getUser();
      final consultations = await ApiService.getConsultations();
      if (!mounted) return;
      consultations.sort(_compareConsultations);
      setState(() {
        _user = user;
        _consultations = consultations;
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

  List<ConsultationModel> get _visible => _filter == 'toutes'
      ? _consultations
      : _consultations.where((item) => item.status == _filter).toList();

  int _countOf(String status) =>
      _consultations.where((c) => c.status == status).length;

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      title: 'Mes consultations',
      subtitle:
          '${_consultations.length} consultation(s) enregistrée(s) · ${_countOf('en_attente')} en attente',
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.doctor(
        userName: _user?.name ?? 'Docteur',
        userSpecialty: _user?.specialty,
        currentSection: NavSection.consultations,
        consultationsPending: _countOf('en_attente'),
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
                  children: _filters.entries.map((entry) {
                    final count = entry.key == 'toutes'
                        ? _consultations.length
                        : _countOf(entry.key);
                    return ChoiceChip(
                      label: Text('${entry.value} ($count)'),
                      selected: _filter == entry.key,
                      onSelected: (_) =>
                          setState(() => _filter = entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                if (_visible.isEmpty)
                  EmptyStateCard(
                    icon: Icons.event_available_rounded,
                    title: 'Aucune consultation trouvée',
                    message:
                        'Aucun dossier ne correspond au filtre « ${_filters[_filter]} ». Changez de filtre ou revenez plus tard.',
                  )
                else
                  ..._visible.map(_tile),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  Widget _tile(ConsultationModel consultation) {
    return ConsultationCard(
      consultation: consultation,
      onRefresh: _load,
      actingId: _actingId,
      onAccept: _accept,
      onDecline: _decline,
    );
  }
}


