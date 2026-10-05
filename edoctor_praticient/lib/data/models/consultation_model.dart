import 'prescription_model.dart';

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
  final PrescriptionModel? prescription;

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
    this.prescription,
  });

  String get displayCode => referenceCode.isNotEmpty ? referenceCode : '#$id';

  bool get isClosed => status == 'terminee' || status == 'annulee';

  String get formattedDateTime {
    final raw = startedAt ?? scheduledAt ?? createdAt;
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '—';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} à ${hour}h$min';
  }

  String get durationText {
    if (startedAt != null && endedAt != null) {
      final start = DateTime.tryParse(startedAt!);
      final end = DateTime.tryParse(endedAt!);
      if (start != null && end != null) {
        final diff = end.difference(start);
        final m = diff.inMinutes;
        if (m < 1) return '< 1 min';
        if (m < 60) return '$m min';
        final h = m ~/ 60;
        final restM = m % 60;
        return restM > 0 ? '${h}h ${restM}min' : '${h}h';
      }
    }
    if (status == 'en_cours' && startedAt != null) {
      final start = DateTime.tryParse(startedAt!);
      if (start != null) {
        final diff = DateTime.now().difference(start);
        final m = diff.inMinutes;
        return 'En cours ($m min)';
      }
      return 'En cours';
    }
    if (status == 'en_attente') return 'En attente';
    if (status == 'annulee') return 'Annulée';
    return '—';
  }

  String get medicationsSummary {
    if (prescription != null && prescription!.items.isNotEmpty) {
      return prescription!.items
          .map((it) => '${it.medicationName}${it.quantity > 1 ? ' (x${it.quantity})' : ''}')
          .join(', ');
    }
    return 'Aucun médicament prescrit';
  }

  factory ConsultationModel.fromJson(Map<String, dynamic> json) {
    String nested(Map<String, dynamic>? m) =>
        m?['name'] as String? ?? '';

    PrescriptionModel? parseRx(dynamic rxRaw) {
      if (rxRaw is Map<String, dynamic>) {
        final pMap = Map<String, dynamic>.from(rxRaw);
        if (pMap['patient'] == null && json['patient'] != null) {
          pMap['patient'] = json['patient'];
        }
        if (pMap['doctor'] == null && json['doctor'] != null) {
          pMap['doctor'] = json['doctor'];
        }
        if (pMap['consultation'] == null) {
          pMap['consultation'] = {'diagnosis': json['diagnosis']};
        }
        return PrescriptionModel.fromJson(pMap);
      }
      return null;
    }

    int parseInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return ConsultationModel(
      id: parseInt(json['id']),
      referenceCode: (json['reference_code'] as String? ?? '').trim(),
      patientId: parseInt(json['patient_id']),
      doctorId: parseInt(json['doctor_id']),
      status: json['status'] as String? ?? 'en_attente',
      scheduledAt: json['scheduled_at'] as String?,
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
      createdAt: json['created_at'] as String?,
      diagnosis: json['diagnosis'] as String?,
      patientName: nested(json['patient'] as Map<String, dynamic>?),
      doctorName: nested(json['doctor'] as Map<String, dynamic>?),
      prescription: parseRx(json['prescription']),
    );
  }
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
    int parseInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    final sender = json['sender'] as Map<String, dynamic>?;
    return ChatMessage(
      id: parseInt(json['id']),
      senderId: parseInt(json['sender_id']),
      content: json['content'] as String? ?? '',
      senderName: sender?['name'] as String? ?? '',
      senderRole: sender?['role'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }
}
