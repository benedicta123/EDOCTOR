import 'video_meeting_config.dart';
import 'video_meeting_service.dart';

/// Cible Web de l'application mobile : la réunion intégrée est portée
/// par la PWA praticien/patient ; les builds natifs utilisent le SDK.
class _UnsupportedVideoMeetingService implements VideoMeetingService {
  static const _message =
      'La vidéo intégrée requiert un build Android ou iOS.';

  @override
  Future<void> join({
    required VideoMeetingConfig config,
    required String displayName,
    required String email,
    bool startAudioMuted = false,
    bool startVideoMuted = false,
    VideoMeetingEvents events = const VideoMeetingEvents(),
  }) =>
      throw UnsupportedError(_message);

  @override
  Future<void> hangUp() async {}

  @override
  Future<void> setAudioMuted(bool muted) async {}

  @override
  Future<void> setVideoMuted(bool muted) async {}

  @override
  void dispose() {}
}

VideoMeetingService createVideoMeetingService() =>
    _UnsupportedVideoMeetingService();
