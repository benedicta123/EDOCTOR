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
  final String patientPhone;
  final String patientAddress;
  final String patientBirthDate;
  final String nurseName;
  final String doctorName;
  final String doctorPhone;
  final String hospitalName;
  final String? bloodPressure;
  final String? bloodGlucose;
  final String? temperature;
  final String? heartRate;
  final List<String> actsPerformed;
  final String? completedAt;

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
    this.patientPhone = '',
    this.patientAddress = '',
    this.patientBirthDate = '',
    this.nurseName = '',
    this.doctorName = '',
    this.doctorPhone = '',
    this.hospitalName = '',
    this.bloodPressure,
    this.bloodGlucose,
    this.temperature,
    this.heartRate,
    this.actsPerformed = const [],
    this.completedAt,
  });

  bool get isPending => status == 'en_attente';
  bool get isAssigned => status == 'assignee';
  bool get isEnRoute => status == 'en_route';
  bool get isCompleted => status == 'terminee';

  String get statusLabel {
    switch (status) {
      case 'assignee':
        return 'Mission assignée';
      case 'en_route':
        return 'En route vers le patient';
      case 'terminee':
        return 'Soins terminés';
      case 'en_attente':
      default:
        return 'En attente d\'affectation';
    }
  }

  factory NurseVisitModel.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>?;
    final nurse = json['nurse'] as Map<String, dynamic>?;
    final hospital = json['hospital'] as Map<String, dynamic>?;
    final prescription = json['prescription'] as Map<String, dynamic>?;
    final doctor = prescription?['doctor'] as Map<String, dynamic>?;

    final rawActs = json['acts_performed'];
    List<String> acts = [];
    if (rawActs is List) {
      acts = rawActs.map((e) => e.toString()).toList();
    }

    return NurseVisitModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      prescriptionId: (json['prescription_id'] as num?)?.toInt() ?? 0,
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      nurseId: (json['nurse_id'] as num?)?.toInt(),
      hospitalId: (json['hospital_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'en_attente',
      scheduledAt: json['scheduled_at'] as String?,
      report: json['report'] as String?,
      patientName: patient?['name'] as String? ?? '',
      patientPhone: patient?['phone'] as String? ?? '',
      patientAddress: patient?['address'] as String? ?? '',
      patientBirthDate: patient?['date_of_birth'] as String? ?? '',
      nurseName: nurse?['name'] as String? ?? '',
      doctorName: doctor?['name'] as String? ?? '',
      doctorPhone: doctor?['phone'] as String? ?? '',
      hospitalName: hospital?['name'] as String? ?? '',
      bloodPressure: json['blood_pressure'] as String?,
      bloodGlucose: json['blood_glucose'] as String?,
      temperature: json['temperature'] as String?,
      heartRate: json['heart_rate'] as String?,
      actsPerformed: acts,
      completedAt: json['completed_at'] as String?,
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
