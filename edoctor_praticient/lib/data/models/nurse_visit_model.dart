class NurseVisitModel {
  final int id;
  final int prescriptionId;
  final int patientId;
  final int? nurseId;
  final int hospitalId;
  final String status;
  final String? scheduledAt;
  final String? report;
  final String patientName;
  final String nurseName;

  const NurseVisitModel({
    required this.id,
    required this.prescriptionId,
    required this.patientId,
    this.nurseId,
    required this.hospitalId,
    required this.status,
    this.scheduledAt,
    this.report,
    this.patientName = '',
    this.nurseName = '',
  });

  factory NurseVisitModel.fromJson(Map<String, dynamic> json) {
    String nested(String key) =>
        (json[key] as Map<String, dynamic>?)?['name'] as String? ?? '';
    return NurseVisitModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      prescriptionId: (json['prescription_id'] as num?)?.toInt() ?? 0,
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      nurseId: (json['nurse_id'] as num?)?.toInt(),
      hospitalId: (json['hospital_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'en_attente',
      scheduledAt: json['scheduled_at'] as String?,
      report: json['report'] as String?,
      patientName: nested('patient'),
      nurseName: nested('nurse'),
    );
  }
}

class AppNotification {
  final int id;
  final String type;
  final String message;
  final bool isRead;

  const AppNotification(
      {required this.id,
      required this.type,
      required this.message,
      this.isRead = false});

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? 'info',
        message: json['message'] as String? ??
            json['data_message'] as String? ??
            '',
        isRead: json['read_at'] != null ||
            json['is_read'] == true ||
            json['isRead'] == true,
      );
}
