import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/consultation_model.dart';
import '../../data/models/user_model.dart';
import '../video/video_call_screen.dart';
import 'find_doctor_screen.dart';

/// Écran de consultation active patient :
/// - Statut en temps réel (polling 5 s)
/// - Chat bidirectionnel avec envoi optimiste
/// - Vidéo JaaS intégrée à l'application (sans navigateur externe)
/// - Bouton annuler si en_attente
class PatientConsultationScreen extends StatefulWidget {
  final ConsultationModel consultation;

  const PatientConsultationScreen({super.key, required this.consultation});

  @override
  State<PatientConsultationScreen> createState() =>
      _PatientConsultationScreenState();
}

class _PatientConsultationScreenState
    extends State<PatientConsultationScreen> {
  late ConsultationModel _consultation;
  List<ChatMessage> _messages = [];
  UserModel? _me;
  bool _loadingMsg = true;
  bool _cancelling = false;

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_PendingMsg> _pending = [];

  Timer? _pollTimer;
  bool _polling = false;
  String? _pollError;

  @override
  void initState() {
    super.initState();
    _consultation = widget.consultation;
    _init();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _silentPoll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();

    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final me = await StorageService.getUser();
    if (!mounted) return;
    setState(() => _me = me);
    await _silentPoll();
  }

  Future<void> _silentPoll() async {
    if (!mounted || _polling) return;
    _polling = true;
    try {
      final consultations = await ApiService.getMyConsultations();
      if (!mounted) return;
      final updated = consultations.firstWhere(
        (c) => c.id == _consultation.id,
        orElse: () => _consultation,
      );
      final wasPending = _consultation.isPending;
      final started = updated.isActive && !_consultation.isActive;
      final wasDeclined = wasPending && (updated.status == 'annulee') && !_cancelling;

      setState(() => _consultation = updated);

      if (wasDeclined) {
        _pollTimer?.cancel();
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.vibrate();

        String? reason;
        if (updated.diagnosis != null && updated.diagnosis!.contains('Refus praticien :')) {
          reason = updated.diagnosis!.replaceFirst('Refus praticien :', '').trim();
        }
        _showDeclinedDialog(doctorName: _consultation.doctorName, reason: reason);
        return;
      }

      final msgs = await ApiService.getMessages(_consultation.id);
      if (!mounted) return;
      final follow = !_scrollCtrl.hasClients ||
          _scrollCtrl.position.extentAfter < 100;
      setState(() {
        _messages = _mergeMessages(msgs);
        _pollError = null;
      });
      if (follow) _scrollDown();
      if (started) _showStartedBanner();
    } catch (_) {
      if (mounted) {
        setState(() => _pollError = 'Actualisation impossible. Réessayez.');
      }
    } finally {
      _polling = false;
      if (mounted) setState(() => _loadingMsg = false);
    }
  }

  List<ChatMessage> _mergeMessages(List<ChatMessage> incoming) {
    final byId = {for (final message in _messages) message.id: message};
    for (final message in incoming) {
      byId[message.id] = message;
    }
    return byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  void _showStartedBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Le Dr ${_consultation.doctorName} a démarré la consultation !',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Rejoindre',
          textColor: Colors.white,
          onPressed: _joinVideo,
        ),
      ),
    );
  }

  Future<void> _showDeclinedDialog({
    required String doctorName,
    String? reason,
  }) async {
    if (!mounted) return;
    final dr = doctorName.isNotEmpty ? doctorName : 'Le praticien';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_disabled_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Consultation déclinée',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le Dr $dr n\'est pas disponible pour cette consultation immédiate.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Motif : $reason',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Vous pouvez solliciter un autre praticien disponible dès maintenant.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const FindDoctorScreen()),
                );
              }
            },
            child: const Text('Trouver un autre médecin'),
          ),
        ],
      ),
    );
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _consultation.isDone) return;
    if (text.runes.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2000 caractères par message.')),
      );
      return;
    }
    _msgCtrl.clear();
    final pm = _PendingMsg(text);
    setState(() => _pending.add(pm));
    _scrollDown();
    unawaited(_postMessage(pm));
  }

  void _retry(_PendingMsg pm) {
    if (!pm.failed || _consultation.isDone) return;
    setState(() => pm.failed = false);
    unawaited(_postMessage(pm));
  }

  Future<void> _postMessage(_PendingMsg pm) async {
    if (!mounted || _consultation.isDone) return;
    try {
      final saved = await ApiService.sendMessage(_consultation.id, pm.text);
      if (!mounted) return;
      setState(() {
        _pending.remove(pm);
        _messages = _mergeMessages([saved]);
        _pollError = null;
      });
      _scrollDown();
    } catch (_) {
      if (!mounted) return;
      setState(() => pm.failed = true);
    }
  }

  /// Ouvre la salle vidéo intégrée (JaaS) sans quitter eDoctor.
  void _joinVideo() {
    if (!_consultation.isActive) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(consultation: _consultation),
      ),
    );
  }

  // ── Annulation ─────────────────────────────────────────────────────
  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Annuler la consultation ?'),
        content: const Text(
          'Cette action est irréversible. Le médecin sera notifié de l\'annulation.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non, garder'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ApiService.cancelConsultation(_consultation.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _consultation.isPending;
    final isActive = _consultation.isActive;
    final isDone = _consultation.isDone;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _consultation.doctorName.isNotEmpty
                  ? 'Dr. ${_consultation.doctorName}'
                  : 'Consultation ${_consultation.displayCode}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            _StatusLabel(status: _consultation.status),
          ],
        ),
        actions: [
          if (isActive)
            IconButton(
              tooltip: 'Rejoindre la vidéo',
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.videocam_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: _joinVideo,
            ),
          if (isPending)
            IconButton(
              tooltip: 'Annuler la demande',
              icon: _cancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close_rounded,
                      color: AppColors.error),
              onPressed: _cancelling ? null : _cancel,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Bandeau de statut ──
          _StatusBanner(
            consultation: _consultation,
            onJoinVideo: isActive ? _joinVideo : null,
          ),
          if (_pollError != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.errorLight,
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 15, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pollError!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // ── Zone de messages ──
          Expanded(
            child: _loadingMsg
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty && _pending.isEmpty
                    ? _EmptyChat(doctorName: _consultation.doctorName)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length + _pending.length,
                        itemBuilder: (_, i) {
                          if (i < _messages.length) {
                            final m = _messages[i];
                            final mine = _me != null &&
                                m.senderId == _me!.id;
                            return _Bubble(
                              content: m.content,
                              author: m.senderName,
                              mine: mine,
                              pending: false,
                              createdAt: m.createdAt,
                            );
                          }
                          final pm = _pending[i - _messages.length];
                          return _Bubble(
                            content: pm.text,
                            author: _me?.name ?? 'Vous',
                            mine: true,
                            pending: true,
                            createdAt: pm.createdAt.toIso8601String(),
                            failed: pm.failed,
                            onRetry: pm.failed
                                ? () => _retry(pm)
                                : null,
                            onDiscard: pm.failed
                                ? () =>
                                    setState(() => _pending.remove(pm))
                                : null,
                          );
                        },
                      ),
          ),

          // ── Saisie de message ──
          if (!isDone) _ChatInput(ctrl: _msgCtrl, onSend: _send),

          if (isDone)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Consultation terminée — historique conservé',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (status) {
      case 'en_attente':
        c = AppColors.warning;
        label = 'En attente d\'acceptation';
        break;
      case 'en_cours':
        c = AppColors.primary;
        label = 'En cours • Vidéo disponible';
        break;
      case 'terminee':
        c = AppColors.textMuted;
        label = 'Terminée';
        break;
      default:
        c = AppColors.error;
        label = 'Annulée';
    }
    return Text(label,
        style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600));
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.consultation,
    this.onJoinVideo,
  });
  final ConsultationModel consultation;
  final VoidCallback? onJoinVideo;

  @override
  Widget build(BuildContext context) {
    if (consultation.isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.warningLight,
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Votre demande a été transmise au médecin. En attente d\'acceptation…',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (consultation.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.primaryContainer,
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Consultation en cours avec Dr. ${consultation.doctorName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onJoinVideo != null)
              TextButton.icon(
                onPressed: onJoinVideo,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.videocam_rounded,
                    color: Colors.white, size: 16),
                label: const Text('Vidéo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.doctorName});
  final String doctorName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.forum_outlined,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun message pour l\'instant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              doctorName.isNotEmpty
                  ? 'Dès que le Dr. $doctorName aura accepté la demande, vous pourrez échanger ici.'
                  : 'Dès que le médecin aura accepté la demande, vous pourrez échanger ici.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.content,
    required this.author,
    required this.mine,
    required this.pending,
    this.createdAt,
    this.failed = false,
    this.onRetry,
    this.onDiscard,
  });
  final String content;
  final String author;
  final bool mine;
  final bool pending;
  final String? createdAt;
  final bool failed;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  String _formatMsgTime(String? iso) {
    if (iso == null || iso.isEmpty) {
      final now = DateTime.now();
      return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: failed
            ? AppColors.errorLight
            : mine
                ? AppColors.primary
                : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: failed
            ? Border.all(color: AppColors.error.withValues(alpha: 0.4))
            : mine
                ? null
                : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: mine ? 0.08 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mine ? 'Vous' : author,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: failed
                      ? AppColors.error
                      : mine
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.primary,
                ),
              ),
              if (pending && !failed) ...[
                const SizedBox(width: 5),
                const SizedBox(
                  width: 9,
                  height: 9,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
              ],
              if (failed) ...[
                const SizedBox(width: 5),
                const Icon(Icons.error_outline_rounded,
                    size: 12, color: AppColors.error),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: failed
                  ? AppColors.error
                  : mine
                      ? Colors.white
                      : AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _formatMsgTime(createdAt),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: failed
                      ? AppColors.error
                      : mine
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.textMuted,
                ),
              ),
              if (mine && !failed) ...[
                const SizedBox(width: 4),
                if (pending)
                  Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                  )
                else
                  Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
              ],
            ],
          ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onRetry,
                    child: const Text(
                      'Réessayer',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onDiscard,
                    child: const Text(
                      'Supprimer',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(onTap: onRetry, child: bubble),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({required this.ctrl, required this.onSend});
  final TextEditingController ctrl;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: ctrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Écrire au médecin…',
                    hintStyle: TextStyle(
                        color: AppColors.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingMsg {
  final String text;
  final DateTime createdAt;
  bool failed = false;
  _PendingMsg(this.text, {DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
}
