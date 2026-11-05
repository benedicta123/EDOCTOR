import 'package:url_launcher/url_launcher.dart';

import 'video_meeting_config.dart';
import 'video_meeting_service.dart';

/// Implémentation Web pour l'application patient :
/// Ouvre directement la visioconférence sécurisée 8x8 JaaS dans un nouvel onglet
/// ou fenêtre avec le token JWT d'authentification.
class WebVideoMeetingService implements VideoMeetingService {
  bool _inCall = false;

  @override
  Future<void> join({
    required VideoMeetingConfig config,
    required String displayName,
    required String email,
    bool startAudioMuted = false,
    bool startVideoMuted = false,
    VideoMeetingEvents events = const VideoMeetingEvents(),
  }) async {
    events.onWillJoin?.call();

    final roomTarget = config.appId.isNotEmpty
        ? '${config.appId}/${config.roomName}'
        : config.roomName;

    // URL 8x8 JaaS officielle avec hash JWT
    final url = 'https://${config.domain}/$roomTarget#jwt=${config.jwt}';
    final uri = Uri.parse(url);

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('Impossible d\'ouvrir la salle de visioconférence.');
    }

    _inCall = true;
    events.onJoined?.call();
  }

  @override
  Future<void> hangUp() async {
    _inCall = false;
  }

  @override
  Future<void> setAudioMuted(bool muted) async {}

  @override
  Future<void> setVideoMuted(bool muted) async {}

  @override
  void dispose() {
    _inCall = false;
  }
}

VideoMeetingService createVideoMeetingService() =>
    WebVideoMeetingService();
