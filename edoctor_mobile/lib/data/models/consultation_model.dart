/// Modèle de consultation partagé côté patient mobile.
class ConsultationModel {
  final int id;
  final String referenceCode;
  final int patientId;
  final int doctorId;
  final String status; // en_attente | en_cours | terminee | annulee
  final String? scheduledAt;
  final String? startedAt;
  final String? endedAt;
  final String? createdAt;
  final String? diagnosis;
  final String patientName;
  final String doctorName;
  final double consultationFee;
  final double edoctorFee;
  final double totalAmount;
  final String paymentStatus;

  const ConsultationModel({
    required this.id,
    this.referenceCode = '',
    required this.patientId,
    required this.doctorId,
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.diagnosis,
    this.patientName = '',
    this.doctorName = '',
    this.consultationFee = 3000.0,
    this.edoctorFee = 600.0,
    this.totalAmount = 3600.0,
    this.paymentStatus = 'en_attente',
  });

  String get displayCode => referenceCode.isNotEmpty ? referenceCode : '#$id';

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    String nested(Map<String, dynamic>? m) => m?['name'] as String? ?? '';
    final cFee = (json['consultation_fee'] as num?)?.toDouble() ?? 3000.0;
    final eFee = (json['edoctor_fee'] as num?)?.toDouble() ?? 600.0;
    final tAmount = (json['total_amount'] as num?)?.toDouble() ?? (cFee + eFee);

    return ConsultationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      referenceCode: (json['reference_code'] as String? ?? '').trim(),
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      doctorId: (json['doctor_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'en_attente',
      scheduledAt: json['scheduled_at'] as String?,
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
      createdAt: json['created_at'] as String?,
      diagnosis: json['diagnosis'] as String?,
      patientName: nested(json['patient'] as Map<String, dynamic>?),
      doctorName: nested(json['doctor'] as Map<String, dynamic>?),
      consultationFee: cFee,
      edoctorFee: eFee,
      totalAmount: tAmount,
      paymentStatus: json['payment_status'] as String? ?? 'en_attente',
    );
  }

  bool get isActive => status == 'en_cours';
  bool get isPending => status == 'en_attente';
  bool get isDone => status == 'terminee' || status == 'annulee';
  bool get isPaid => paymentStatus == 'paye';
}

class ChatMessage {
  final int id;
  final int senderId;
  final String content;
  final String senderName;
  final String senderRole;
  final String? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    this.senderName = '',
    this.senderRole = '',
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      senderName: sender?['name'] as String? ?? '',
      senderRole: sender?['role'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }

  bool get isFromDoctor => senderRole == 'doctor';
}

class AppNotification {
  final int id;
  final String type;
  final String message;
  final bool isRead;
  final String? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      // L'API Laravel expose le texte dans `content` (modèle Notification).
      message: (json['content'] ?? json['message']) as String? ?? '',
      isRead: json['read'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }
}
