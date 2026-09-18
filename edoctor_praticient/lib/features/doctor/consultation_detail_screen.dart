import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/praticien_nav.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/prescription_model.dart';
import '../../data/models/user_model.dart';
import '../auth/login_screen.dart';
import 'patient_dossier_screen.dart';
import 'video_consultation_screen.dart';

/// Fiche consultation médecin : actions statut + chat optimiste + vidéo + ordonnance.
class ConsultationDetailScreen extends StatefulWidget {
  final ConsultationModel consultation;
  const ConsultationDetailScreen({super.key, required this.consultation});
  @override
  State<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  List<ChatMessage> _messages = [];
  List<MedicationModel> _catalog = [];
  UserModel? _me;
  bool _loading = true;
  final _msgCtrl = TextEditingController();
  final _msgScroll = ScrollController();

  // Chat optimiste : les envois apparaissent instantanément, sans bloquer
  // la saisie du message suivant.
  final List<_PendingMsg> _pending = [];
  Timer? _refreshDebounce;
  Timer? _incomingPoll;

  // Ordonnance
  final List<Map<String, dynamic>> _items = [];
  int? _medId;
  final _dosage = TextEditingController();
  final _qty = TextEditingController(text: '1');
  bool _homeCare = false;
  bool _creatingRx = false;
  List<PrescriptionModel> _consultationRx = [];

  // Diagnostic (note médicale obligatoire avant clôture)
  final _diagnosis = TextEditingController();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Les réponses du patient arrivent sans manipulation, toutes les 5 s.
    _incomingPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pending.isEmpty) _silentReload();
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _dosage.dispose();
    _qty.dispose();
    _diagnosis.dispose();
    _msgScroll.dispose();
    _refreshDebounce?.cancel();
    _incomingPoll?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await StorageService.getUser();
      final msgs = await ApiService.getMessages(widget.consultation.id);
      List<MedicationModel> catalog = [];
      try {
        catalog = await ApiService.getMedications();
      } catch (_) {}
      final rx = await _fetchConsultationRx();
      if (!mounted) return;
      setState(() {
        _me = me;
        _messages = msgs;
        _catalog = catalog;
        _consultationRx = rx;
        if (_diagnosis.text.isEmpty) {
          _diagnosis.text = widget.consultation.diagnosis ?? '';
        }
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showMsg(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    }
  }

  Future<List<PrescriptionModel>> _fetchConsultationRx() async {
    try {
      final all = await ApiService.getPrescriptions();
      return all
          .where((p) =>
              p.consultationId == widget.consultation.id &&
              p.status == 'validee')
          .toList();
    } catch (_) {
      return _consultationRx;
    }
  }

  /// Recharge la conversation sans spinners ni blocage (polling / réconciliation).
  Future<void> _silentReload() async {
    try {
      final msgs = await ApiService.getMessages(widget.consultation.id);
      if (!mounted) return;
      setState(() => _messages = msgs);
      _scrollToBottom();
    } catch (_) {}
  }

  void _scheduleReconcile() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 900), _silentReload);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_msgScroll.hasClients) return;
      _msgScroll.jumpTo(_msgScroll.position.maxScrollExtent);
    });
  }

  Future<void> _action(String action, String ok) async {
    try {
      await ApiService.consultationAction(widget.consultation.id, action);
      if (mounted) {
        showMsg(context, ok);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showMsg(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    }
  }

  /// Clôture : exige le diagnostic ET au moins une ordonnance validée
  /// liée à cette consultation avant d'appeler l'API.
  Future<void> _closeConsultation() async {
    if (_closing) return;
    if (_diagnosis.text.trim().isEmpty) {
      showMsg(context,
          'Posez d’abord le diagnostic (note médicale) avant de clôturer.',
          error: true);
      return;
    }
    final rx = await _fetchConsultationRx();
    if (!mounted) return;
    setState(() => _consultationRx = rx);
    if (rx.isEmpty) {
      showMsg(context,
          'Rédigez d’abord l’ordonnance de cette consultation avant de clôturer.',
          error: true);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Clôturer la consultation ?'),
        content: Text(
          'Diagnostic enregistré et ordonnance #${rx.first.id} liée. '
          'Les échanges seront clos et aucune modification ne sera plus possible.',
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vérifier encore'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _closing = true);
    try {
      await ApiService.endConsultation(
        widget.consultation.id,
        diagnosis: _diagnosis.text,
      );
      if (mounted) {
        showMsg(context, 'Consultation clôturée');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showMsg(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  // ── Chat optimiste ────────────────────────────────────────────────

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    final pm = _PendingMsg(text);
    setState(() => _pending.add(pm));
    _scrollToBottom();
    unawaited(_dispatch(pm));
  }

  Future<void> _dispatch(_PendingMsg pm) async {
    pm.failed = false;
    try {
      await ApiService.sendMessage(widget.consultation.id, pm.text);
      if (!mounted) return;
      setState(() => _pending.remove(pm));
      _scheduleReconcile();
    } catch (_) {
      if (!mounted) return;
      setState(() => pm.failed = true);
    }
  }

  // ── Ordonnance ────────────────────────────────────────────────────

  void _addItem() {
    if (_medId == null || _dosage.text.trim().isEmpty) {
      showMsg(context, 'Choisissez un médicament et sa posologie', error: true);
      return;
    }
    final med = _catalog.firstWhere((m) => m.id == _medId);
    setState(() {
      _items.add({
        'medication_id': med.id,
        'medication_name': med.name,
        'dosage_instructions': _dosage.text.trim(),
        'quantity': int.tryParse(_qty.text.trim()) ?? 1,
      });
      _dosage.clear();
      _qty.text = '1';
    });
  }

  Future<void> _createRx() async {
    if (_items.isEmpty) {
      showMsg(context, 'Ajoutez au moins un médicament', error: true);
      return;
    }
    setState(() => _creatingRx = true);
    try {
      final rx = await ApiService.createPrescription(
        consultationId: widget.consultation.id,
        homeCareRecommended: _homeCare,
        items: _items
            .map((e) => {
                  'medication_id': e['medication_id'],
                  'dosage_instructions': e['dosage_instructions'],
                  'quantity': e['quantity'],
                })
            .toList(),
      );
      final fresh = await _fetchConsultationRx();
      if (mounted) {
        showMsg(context, 'Ordonnance #${rx.id} créée');
        setState(() {
          _items.clear();
          _consultationRx = fresh;
        });
      }
    } catch (e) {
      if (mounted) {
        showMsg(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _creatingRx = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consultation;
    return ResponsiveShell(
      title: 'Consultation #${c.id}',
      subtitle: c.patientName.isEmpty
          ? 'Patient #${c.patientId}'
          : c.patientName,
      scrollable: true,
      onRefresh: _load,
      nav: PraticienNav.doctor(
        userName: _me?.name ?? 'Docteur',
        userSpecialty: _me?.specialty,
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
                if (c.isClosed) _buildClosedBanner(),
                _buildActionBar(c),
                const SizedBox(height: 20),
                const Text(
                  'Messagerie patient',
                  style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                _buildChat(c),
                if (c.status == 'en_cours') ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Diagnostic (note médicale)',
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  _buildDiagnosisEditor(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        'Rédiger l’ordonnance',
                        style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      if (_consultationRx.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_consultationRx.length} liée(s)',
                            style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildPrescriptionForm(),
                ],
                if (c.isClosed) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Diagnostic posé',
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  _buildDiagnosisReadOnly(c),
                  if (_consultationRx.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Ordonnance liée (#${_consultationRx.first.id})',
                      style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    ..._consultationRx.map(_buildLinkedRxCard),
                  ],
                ],
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  // ── Bandeau statut + actions ──────────────────────────────────────

  Widget _buildActionBar(ConsultationModel c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusChip(status: c.status),
          if (c.status == 'en_attente') ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => VideoConsultation.launch(context, c,
                      startIfNeeded: true)
                  .then((_) => _load()),
              icon: const Icon(Icons.videocam_rounded, size: 18),
              label: const Text('Démarrer en vidéo'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _action('start', 'Consultation démarrée'),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Démarrer'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: AppColors.error,
                side:
                    BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _action('decline', 'Demande déclinée'),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Refuser'),
            ),
          ],
          if (c.status == 'en_cours') ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => VideoConsultation.launch(context, c,
                      startIfNeeded: false)
                  .then((_) => _load()),
              icon: const Icon(Icons.videocam_rounded, size: 18),
              label: const Text('Rejoindre la vidéo'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _closing ? null : _closeConsultation,
              icon: _closing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_closing ? 'Clôture…' : 'Terminer'),
            ),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PatientDossierScreen(
                    patientId: c.patientId, patientName: c.patientName))),
            icon: const Icon(Icons.folder_shared_rounded, size: 18),
            label: const Text('Dossier patient'),
          ),
        ],
      ),
    );
  }

  // ── Bandeau de clôture + diagnostic ───────────────────────────────

  Widget _buildClosedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 20, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Consultation clôturée : les échanges sont clos, le diagnostic et l’ordonnance ne sont plus modifiables.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisEditor() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Décrivez le diagnostic et les recommandations. Ce texte sera exigé pour clôturer la consultation.',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _diagnosis,
            maxLines: 4,
            minLines: 3,
            maxLength: 5000,
            decoration: const InputDecoration(
              hintText: 'Ex. Paludisme simple probable — TDR à confirmer…',
              prefixIcon: Icon(Icons.notes_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisReadOnly(ConsultationModel c) {
    final text = (c.diagnosis ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notes_rounded,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.isEmpty ? 'Aucun diagnostic renseigné.' : text,
              style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedRxCard(PrescriptionModel rx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Consultation #${rx.consultationId}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const Spacer(),
              StatusChip(status: rx.status),
            ],
          ),
          const SizedBox(height: 10),
          ...rx.items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.medication_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${it.medicationName} — ${it.dosageInstructions} (qté ${it.quantity})',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Chat ──────────────────────────────────────────────────────────

  Widget _buildChat(ConsultationModel c) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: _messages.isEmpty && _pending.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(Icons.forum_outlined,
                            size: 34, color: AppColors.textMuted),
                        SizedBox(height: 10),
                        Text(
                          'Aucun message pour le moment',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Écrivez ci-dessous pour informer votre patient.',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _msgScroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(14),
                    itemCount: _messages.length + _pending.length,
                    itemBuilder: (_, i) {
                      if (i < _messages.length) {
                        final m = _messages[i];
                        final mine = _me != null && m.senderId == _me!.id;
                        return _bubble(
                          content: m.content,
                          author: m.senderName,
                          mine: mine,
                          pending: false,
                        );
                      }
                      final pm = _pending[i - _messages.length];
                      return _bubble(
                        content: pm.text,
                        author: _me?.name ?? 'Vous',
                        mine: true,
                        pending: true,
                        failed: pm.failed,
                        onRetry: pm.failed
                            ? () => unawaited(_dispatch(pm))
                            : null,
                        onDiscard: pm.failed
                            ? () => setState(() => _pending.remove(pm))
                            : null,
                      );
                    },
                  ),
          ),
          if (c.isClosed)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Text(
                    'Échanges clos — consultation terminée',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                          hintText: 'Écrire au patient…',
                          prefixIcon: Icon(Icons.edit_note_rounded)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Envoyer',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bubble({
    required String content,
    required String author,
    required bool mine,
    required bool pending,
    bool failed = false,
    VoidCallback? onRetry,
    VoidCallback? onDiscard,
  }) {
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: failed
            ? AppColors.errorLight
            : mine
                ? AppColors.primaryContainer
                : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: failed
            ? Border.all(color: AppColors.error.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                author,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: failed
                      ? AppColors.error
                      : mine
                          ? AppColors.primaryHover
                          : AppColors.textSecondary,
                ),
              ),
              if (pending && !failed) ...[
                const SizedBox(width: 5),
                const SizedBox(
                  width: 9,
                  height: 9,
                  child: CircularProgressIndicator(strokeWidth: 1.4),
                ),
              ],
              if (failed) ...[
                const SizedBox(width: 5),
                const Icon(Icons.error_outline_rounded,
                    size: 12, color: AppColors.error),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(content),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Non envoyé — touchez pour réessayer',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.error.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onDiscard,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded,
                          size: 13, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(14),
        child: pending && !failed
            ? Opacity(opacity: 0.72, child: bubble)
            : bubble,
      ),
    );
  }

  // ── Formulaire d'ordonnance ───────────────────────────────────────

  Widget _buildPrescriptionForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_catalog.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _medId,
              decoration: const InputDecoration(
                  labelText: 'Médicament',
                  prefixIcon: Icon(Icons.medication_rounded, size: 20)),
              items: _catalog
                  .map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _medId = v),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Catalogue de médicaments inaccessible — vérifiez que l’API eDoctor est démarrée.',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: CustomTextField(
                    controller: _dosage,
                    label: 'Posologie',
                    hint: '1 cp × 2/j pendant 7 jours'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomTextField(
                    controller: _qty,
                    label: 'Qté',
                    keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter à l’ordonnance'),
          ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._items.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e['medication_name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: Text(
                        '${e['dosage_instructions']} · quantité ${e['quantity']}',
                        style: const TextStyle(fontSize: 12.5)),
                    trailing: IconButton(
                      tooltip: 'Retirer',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error),
                      onPressed: () => setState(() => _items.remove(e)),
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            title: const Text('Soins à domicile recommandés',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text(
                'Proposera une prise en charge à domicile au patient',
                style: TextStyle(fontSize: 12.5)),
            value: _homeCare,
            onChanged: (v) => setState(() => _homeCare = v),
          ),
          const SizedBox(height: 8),
          CustomButton(
            label: 'Créer l’ordonnance',
            isLoading: _creatingRx,
            onPressed: _createRx,
          ),
        ],
      ),
    );
  }
}

class _PendingMsg {
  final String text;
  bool failed = false;
  _PendingMsg(this.text);
}
