import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/video/video_meeting.dart';
import '../../core/services/video/video_meeting_config.dart';
import '../../core/services/video/video_meeting_service.dart';
import '../../data/models/consultation_model.dart';

/// Salle vidéo intégrée à eDoctor (JaaS) : la réunion s'ouvre dans
/// l'application via le SDK natif — jamais dans un navigateur externe
/// ni dans l'application Jitsi tierce.
class VideoCallScreen extends StatefulWidget {
  final ConsultationModel consultation;

  const VideoCallScreen({super.key, required this.consultation});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

enum _CallPhase { loading, ready, joining, inCall, ended, error }

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final VideoMeetingService _service;
  VideoMeetingConfig? _config;
  String? _userName;
  String? _userEmail;
  _CallPhase _phase = _CallPhase.loading;
  String? _error;
  String _status = 'Préparation de la salle…';
  int _participants = 1;
  bool _micOn = true;
  bool _camOn = true;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _service = createVideoMeetingService();
    _prepare();
  }

  @override
  void dispose() {
    // Nettoyage : quitte la réunion si l'écran est abandonné en appel.
    _service.hangUp();
    _service.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final user = await StorageService.getUser();
      final config =
          await ApiService.joinConsultation(widget.consultation.id);
      if (!mounted) return;
      setState(() {
        _config = config;
        _userName = (user?.name.isNotEmpty == true)
            ? user!.name
            : 'Patient eDoctor';
        _userEmail = user?.email ?? '';
        _phase = _CallPhase.ready;
        _status = 'Salle sécurisée prête.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CallPhase.error;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _join() async {
    final config = _config;
    if (config == null || _phase == _CallPhase.joining) return;
    setState(() {
      _phase = _CallPhase.joining;
      _status = 'Connexion à la salle…';
      _error = null;
    });
    try {
      await _service.join(
        config: config,
        displayName: _userName ?? 'Patient eDoctor',
        email: _userEmail ?? '',
        startAudioMuted: !_micOn,
        startVideoMuted: !_camOn,
        events: VideoMeetingEvents(
          onWillJoin: () {
            if (!mounted) return;
            setState(() => _status = 'Connexion à la salle…');
          },
          onJoined: () {
            if (!mounted) return;
            setState(() {
              _phase = _CallPhase.inCall;
              _status = 'Connecté — consultation en vidéo.';
            });
          },
          onParticipantJoined: (name) {
            if (!mounted) return;
            setState(() {
              _participants += 1;
              _status = '${name ?? 'Le médecin'} a rejoint la salle.';
            });
          },
          onParticipantLeft: () {
            if (!mounted) return;
            setState(() {
              _participants = _participants > 1 ? _participants - 1 : 1;
              _status = 'En attente de l’autre participant…';
            });
          },
          onTerminated: (error) {
            if (!mounted) return;
            if (error != null) {
              setState(() {
                _phase = _CallPhase.error;
                _error = error.toString();
              });
            } else {
              setState(() {
                _phase = _CallPhase.ended;
                _status = 'Appel terminé.';
              });
            }
          },
          onReadyToClose: () {
            if (mounted) Navigator.of(context).maybePop();
          },
        ),
      );
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CallPhase.error;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _CallPhase.ready;
        _error = e.toString().replaceFirst('Exception: ', '');
        _status = 'Échec de connexion — vérifiez le réseau puis réessayez.';
      });
    }
  }

  /// Quitter AU MIEUX avec confirmation si l'appel est actif :
  /// le départ ne clôture jamais la consultation côté API.
  Future<bool> _confirmLeave() async {
    if (_phase != _CallPhase.inCall &&
        _phase != _CallPhase.joining) {
      return true;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Quitter la réunion ?'),
        content: const Text(
          'Vous quitterez la vidéo, mais la consultation restera en cours. Vous pourrez la rejoindre à nouveau.',
          style:
              TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Rester'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _leave() async {
    if (_leaving) return;
    if (!await _confirmLeave()) return;
    setState(() => _leaving = true);
    await _service.hangUp();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consultation;
    return PopScope(
      canPop: _phase != _CallPhase.inCall &&
          _phase != _CallPhase.joining,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Quitter la réunion',
            icon: const Icon(Icons.call_end_rounded),
            onPressed: _leave,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Consultation vidéo',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Text(
                c.doctorName.isNotEmpty
                    ? 'Dr. ${c.doctorName} · Consultation #${c.id}'
                    : 'Consultation #${c.id}',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusCard(
                    status: _status, participants: _participants),
                const SizedBox(height: 16),
                Expanded(child: _buildPhaseBody()),
                const SizedBox(height: 12),
                if (_phase == _CallPhase.ready ||
                    _phase == _CallPhase.joining)
                  _PreJoinControls(
                    micOn: _micOn,
                    camOn: _camOn,
                    joining: _phase == _CallPhase.joining,
                    onToggleMic: () =>
                        setState(() => _micOn = !_micOn),
                    onToggleCam: () =>
                        setState(() => _camOn = !_camOn),
                    onJoin: _join,
                  ),
                if (_phase == _CallPhase.inCall)
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14)),
                      ),
                      onPressed: _leave,
                      icon: const Icon(Icons.call_end_rounded,
                          color: Colors.white),
                      label: const Text('Quitter la réunion',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (_phase == _CallPhase.ended)
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retour à la consultation'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseBody() {
    switch (_phase) {
      case _CallPhase.loading:
      case _CallPhase.joining:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 14),
              Text('Ouverture de la salle sécurisée…',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      case _CallPhase.inCall:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_rounded,
                  size: 56, color: Colors.white24),
              SizedBox(height: 12),
              Text(
                'Réunion en cours dans la vue native.\nUtilisez sa barre d’outils (micro, caméra, chat).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        );
      case _CallPhase.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              Text(
                _error ?? 'Salle vidéo inaccessible.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, height: 1.5),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                            color: Colors.white38)),
                    onPressed: () {
                      setState(() {
                        _phase = _CallPhase.loading;
                        _error = null;
                      });
                      _prepare();
                    },
                    icon: const Icon(Icons.refresh_rounded,
                        size: 18),
                    label: const Text('Réessayer'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    child: const Text('Retour'),
                  ),
                ],
              ),
            ],
          ),
        );
      case _CallPhase.ended:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 52, color: AppColors.primaryLight),
              SizedBox(height: 12),
              Text('Appel terminé.',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('La consultation reste ouverte dans eDoctor.',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      case _CallPhase.ready:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded,
                    size: 36, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 14),
              const Text(
                'Salle sécurisée eDoctor',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chiffrée · sans quitter l’application.',
                style:
                    TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12)),
              ],
            ],
          ),
        );
    }
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  final int participants;
  const _StatusCard({required this.status, required this.participants});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(status,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.people_rounded,
              size: 16, color: Colors.white70),
          const SizedBox(width: 4),
          Text('$participants',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PreJoinControls extends StatelessWidget {
  final bool micOn;
  final bool camOn;
  final bool joining;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCam;
  final VoidCallback onJoin;

  const _PreJoinControls({
    required this.micOn,
    required this.camOn,
    required this.joining,
    required this.onToggleMic,
    required this.onToggleCam,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ToggleTile(
                icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                label: 'Micro',
                active: micOn,
                onTap: joining ? null : onToggleMic,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToggleTile(
                icon: camOn
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                label: 'Caméra',
                active: camOn,
                onTap: joining ? null : onToggleCam,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: joining ? null : onJoin,
            icon: joining
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.video_call_rounded,
                    color: Colors.white),
            label: Text(joining ? 'Connexion…' : 'Rejoindre',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active
                  ? AppColors.primaryLight
                  : Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
