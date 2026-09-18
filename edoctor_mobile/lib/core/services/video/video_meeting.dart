import 'video_meeting_service.dart';
import 'video_meeting_service_mobile.dart'
    if (dart.library.js_interop) 'video_meeting_service_web.dart'
    as impl;

/// Fabrique multiplateforme : SDK natif sur Android/iOS,
/// erreur explicite sur Web (ni SDK mobile, ni navigateur externe).
VideoMeetingService createVideoMeetingService() =>
    impl.createVideoMeetingService();
