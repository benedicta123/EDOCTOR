import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import 'video_meeting_config.dart';
import 'video_meeting_service.dart';

/// Implémentation Android/iOS via le SDK Jitsi officiel.
/// La réunion s'ouvre dans l'activité native de l'application :
/// ni navigateur externe, ni application Jitsi tierce.
class MobileVideoMeetingService implements VideoMeetingService {
  final JitsiMeet _jitsi = JitsiMeet();
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
    final options = JitsiMeetConferenceOptions(
      serverURL: config.serverUrl,
      room: config.roomName,
      token: config.jwt,
      userInfo: JitsiMeetUserInfo(
        displayName: displayName,
        email: email,
      ),
      configOverrides: {
        'startWithAudioMuted': startAudioMuted,
        'startWithVideoMuted': startVideoMuted,
        'prejoinPageEnabled': false,
      },
      featureFlags: {
        'welcomepage.enabled': false,
        'invite.enabled': false,
        'call-integration.enabled': false,
        'pip.enabled': true,
      },
    );

    final listener = JitsiMeetEventListener(
      conferenceWillJoin: (_) => events.onWillJoin?.call(),
      conferenceJoined: (_) {
        _inCall = true;
        events.onJoined?.call();
      },
      conferenceTerminated: (_, error) {
        _inCall = false;
        events.onTerminated?.call(error);
      },
      participantJoined: (email, name, role, participantId) =>
          events.onParticipantJoined?.call(name ?? email),
      participantLeft: (_) => events.onParticipantLeft?.call(),
      readyToClose: () => events.onReadyToClose?.call(),
    );

    final response = await _jitsi.join(options, listener);
    if (response.isSuccess == false) {
      throw Exception(response.message?.isNotEmpty == true
          ? response.message!
          : 'Connexion à la salle vidéo impossible.');
    }
  }

  @override
  Future<void> hangUp() async {
    if (!_inCall) return;
    try {
      await _jitsi.hangUp();
    } catch (_) {
      // Quitter au mieux : l'écran se ferme dans tous les cas.
    } finally {
      _inCall = false;
    }
  }

  @override
  Future<void> setAudioMuted(bool muted) => _jitsi.setAudioMuted(muted);

  @override
  Future<void> setVideoMuted(bool muted) => _jitsi.setVideoMuted(muted);

  @override
  void dispose() {
    _inCall = false;
  }
}

VideoMeetingService createVideoMeetingService() =>
    MobileVideoMeetingService();
