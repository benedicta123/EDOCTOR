import 'package:flutter_test/flutter_test.dart';

import 'package:edoctor_mobile/core/services/video/video_meeting.dart';
import 'package:edoctor_mobile/core/services/video/video_meeting_config.dart';
import 'package:edoctor_mobile/core/services/video/video_meeting_service.dart';

void main() {
  group('VideoMeetingConfig', () {
    test('parse la réponse join de Laravel', () {
      final config = VideoMeetingConfig.fromJson({
        'server_url': 'https://8x8.vc/test-app',
        'domain': '8x8.vc',
        'app_id': 'test-app',
        'room_name': 'edoctor-abc123',
        'jwt': 'a.b.c',
        'expires_at': '2026-09-17T15:30:00Z',
      });

      expect(config.isValid, isTrue);
      expect(config.serverUrl, 'https://8x8.vc/test-app');
      expect(config.roomName, 'edoctor-abc123');
      expect(config.expiresAt?.year, 2026);
    });

    test('config incomplète invalide', () {
      const config = VideoMeetingConfig(
        serverUrl: '',
        domain: '',
        appId: '',
        roomName: '',
        jwt: '',
      );
      expect(config.isValid, isFalse);
    });

    test('aucune donnée médicale dans le nom de salle', () {
      final config = VideoMeetingConfig.fromJson({
        'server_url': 'https://8x8.vc/test-app',
        'domain': '8x8.vc',
        'app_id': 'test-app',
        'room_name': 'edoctor-9f42c91e77aa01bc',
        'jwt': 'a.b.c',
      });
      expect(config.roomName.startsWith('edoctor-'), isTrue);
      expect(config.roomName.contains('patient'), isFalse);
    });
  });

  group('VideoMeetingService', () {
    test('fabrique retourne une implémentation', () {
      final service = createVideoMeetingService();
      expect(service, isA<VideoMeetingService>());
      service.dispose();
    });
  });
}
