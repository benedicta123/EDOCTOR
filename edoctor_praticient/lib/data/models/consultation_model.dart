class ConsultationModel {
  final int id;
  final int patientId;
  final int doctorId;
  final String status; // en_attente | en_cours | terminee | annulee
  final String? scheduledAt;
  final String? startedAt;
  final String? endedAt;
  final String? diagnosis;
  final String patientName;
  final String doctorName;

  const ConsultationModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.diagnosis,
    this.patientName = '',
    this.doctorName = '',
  });

  bool get isClosed => status == 'terminee' || status == 'annulee';

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    String nested(Map<String, dynamic>? m) =>
        m?['name'] as String? ?? '';
    return ConsultationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      doctorId: (json['doctor_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'en_attente',
      scheduledAt: json['scheduled_at'] as String?,
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
      diagnosis: json['diagnosis'] as String?,
      patientName: nested(json['patient'] as Map<String, dynamic>?),
      doctorName: nested(json['doctor'] as Map<String, dynamic>?),
    );
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final String content;
  final String senderName;
  final String senderRole;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    this.senderName = '',
    this.senderRole = '',
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      senderName: sender?['name'] as String? ?? '',
      senderRole: sender?['role'] as String? ?? '',
    );
  }
}
