/// Ordonnance patient — 100 % données API (GET /api/prescriptions).
class PrescriptionItemModel {
  final int medicationId;
  final String medicationName;
  final String dosageInstructions;
  final int quantity;

  const PrescriptionItemModel({
    required this.medicationId,
    required this.medicationName,
    required this.dosageInstructions,
    required this.quantity,
  });

  factory PrescriptionItemModel.fromJson(Map<String, dynamic> json) {
    final med = json['medication'] as Map<String, dynamic>?;
    return PrescriptionItemModel(
      medicationId: (json['medication_id'] as num?)?.toInt() ?? (med?['id'] as num?)?.toInt() ?? 1,
      medicationName: (med?['name'] ?? med?['commercial_name']) as String? ??
          'Médicament',
      dosageInstructions:
          json['dosage_instructions'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class PatientPrescription {
  final int id;
  final int consultationId;
  final String? consultationReferenceCode;
  final int doctorId;
  final String doctorName;
  final String patientName;
  final String patientAge;
  final String patientPhone;
  final String hospitalName;
  final String diagnosis;
  final String status; // validee | annulee
  final bool homeCareRecommended;
  final String? createdAt;
  final List<PrescriptionItemModel> items;
  final Map<String, dynamic>? order;

  const PatientPrescription({
    required this.id,
    required this.consultationId,
    this.consultationReferenceCode,
    required this.doctorId,
    this.doctorName = '',
    this.patientName = 'Patient eDoctor',
    this.patientAge = 'Âge non spécifié',
    this.patientPhone = '',
    this.hospitalName = 'Centre Hospitalier Universitaire de Démo',
    this.diagnosis = 'Non spécifié',
    required this.status,
    this.homeCareRecommended = false,
    this.createdAt,
    this.items = const [],
    this.order,
  });

  bool get isActive => status == 'validee';
  bool get hasOrder => order != null;

  String get consultationDisplayCode {
    if (consultationReferenceCode != null && consultationReferenceCode!.trim().isNotEmpty) {
      return consultationReferenceCode!;
    }
    return '#$consultationId';
  }

  String get formattedDate {
    if (createdAt == null) return 'Récemment';
    final dt = DateTime.tryParse(createdAt!);
    if (dt == null) return 'Récemment';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  factory PatientPrescription.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'] as Map<String, dynamic>?;
    final patient = json['patient'] as Map<String, dynamic>?;
    final consultation = json['consultation'] as Map<String, dynamic>?;
    final hospital = doctor?['hospital'] as Map<String, dynamic>?;

    String calculateAge(String? dobStr) {
      if (dobStr == null || dobStr.isEmpty) return 'Âge non spécifié';
      final dob = DateTime.tryParse(dobStr);
      if (dob == null) return 'Âge non spécifié';
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return '$age ans';
    }

    final items = (json['items'] as List? ?? [])
        .map((e) =>
            PrescriptionItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return PatientPrescription(
      id: (json['id'] as num?)?.toInt() ?? 0,
      consultationId: (json['consultation_id'] as num?)?.toInt() ?? 0,
      consultationReferenceCode: consultation?['reference_code'] as String?,
      doctorId: (json['doctor_id'] as num?)?.toInt() ?? 0,
      doctorName: doctor?['name'] as String? ?? 'Dr. Praticien',
      patientName: patient?['name'] as String? ?? 'Patient eDoctor',
      patientAge: calculateAge(patient?['date_of_birth'] as String?),
      patientPhone: patient?['phone'] as String? ?? '',
      hospitalName: hospital?['name'] as String? ?? 'Centre Hospitalier Universitaire de Démo',
      diagnosis: consultation?['diagnosis'] as String? ?? 'Non spécifié',
      status: json['status'] as String? ?? 'validee',
      homeCareRecommended:
          json['home_care_recommended'] == true ||
              json['home_care_recommended'] == 1,
      createdAt: json['created_at'] as String?,
      items: items,
      order: json['order'] as Map<String, dynamic>?,
    );
  }
}
