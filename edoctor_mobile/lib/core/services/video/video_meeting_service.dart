import 'video_meeting_config.dart';

/// Événements de réunion exposés à l'UI, quel que soit le backend natif.
class VideoMeetingEvents {
  final void Function()? onWillJoin;
  final void Function()? onJoined;
  final void Function(Object? error)? onTerminated;
  final void Function(String? name)? onParticipantJoined;
  final void Function()? onParticipantLeft;
  final void Function()? onReadyToClose;

  const VideoMeetingEvents({
    this.onWillJoin,
    this.onJoined,
    this.onTerminated,
    this.onParticipantJoined,
    this.onParticipantLeft,
    this.onReadyToClose,
  });
}

/// Abstraction commune : Android/iOS via SDK Jitsi, Web via IFrame API.
/// L'écran applicatif ne dépend que de cette interface.
abstract class VideoMeetingService {
  Future<void> join({
    required VideoMeetingConfig config,
    required String displayName,
    required String email,
    bool startAudioMuted = false,
    bool startVideoMuted = false,
    VideoMeetingEvents events = const VideoMeetingEvents(),
  });

  Future<void> hangUp();
  Future<void> setAudioMuted(bool muted);
  Future<void> setVideoMuted(bool muted);
  void dispose();
}
