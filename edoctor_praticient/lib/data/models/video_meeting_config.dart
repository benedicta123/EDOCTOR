/// Configuration de salle vidéo fournie par Laravel
/// (POST /api/consultations/{id}/join). JWT éphémère, usage en mémoire.
class VideoMeetingConfig {
  final String serverUrl;
  final String domain;
  final String appId;
  final String roomName;
  final String jwt;
  final DateTime? expiresAt;

  const VideoMeetingConfig({
    required this.serverUrl,
    required this.domain,
    required this.appId,
    required this.roomName,
    required this.jwt,
    this.expiresAt,
  });

  factory VideoMeetingConfig.fromJson(Map<String, dynamic> json) {
    DateTime? expires;
    final raw = json['expires_at'] as String?;
    if (raw != null && raw.isNotEmpty) {
      expires = DateTime.tryParse(raw);
    }
    return VideoMeetingConfig(
      serverUrl: json['server_url'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      appId: json['app_id'] as String? ?? '',
      roomName: json['room_name'] as String? ?? '',
      jwt: json['jwt'] as String? ?? '',
      expiresAt: expires,
    );
  }

  bool get isValid =>
      serverUrl.isNotEmpty &&
      domain.isNotEmpty &&
      appId.isNotEmpty &&
      roomName.isNotEmpty &&
      jwt.isNotEmpty;
}
