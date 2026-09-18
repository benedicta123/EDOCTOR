/// Ordonnance patient — 100 % données API (GET /api/prescriptions).
class PrescriptionItemModel {
  final String medicationName;
  final String dosageInstructions;
  final int quantity;

  const PrescriptionItemModel({
    required this.medicationName,
    required this.dosageInstructions,
    required this.quantity,
  });

  factory PrescriptionItemModel.fromJson(Map<String, dynamic> json) {
    final med = json['medication'] as Map<String, dynamic>?;
    return PrescriptionItemModel(
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
  final int doctorId;
  final String doctorName;
  final String status; // validee | annulee
  final bool homeCareRecommended;
  final String? createdAt;
  final List<PrescriptionItemModel> items;

  const PatientPrescription({
    required this.id,
    required this.consultationId,
    required this.doctorId,
    this.doctorName = '',
    required this.status,
    this.homeCareRecommended = false,
    this.createdAt,
    this.items = const [],
  });

  factory PatientPrescription.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'] as Map<String, dynamic>?;
    final items = (json['items'] as List? ?? [])
        .map((e) =>
            PrescriptionItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return PatientPrescription(
      id: (json['id'] as num?)?.toInt() ?? 0,
      consultationId: (json['consultation_id'] as num?)?.toInt() ?? 0,
      doctorId: (json['doctor_id'] as num?)?.toInt() ?? 0,
      doctorName: doctor?['name'] as String? ?? '',
      status: json['status'] as String? ?? 'validee',
      homeCareRecommended:
          json['home_care_recommended'] == true ||
              json['home_care_recommended'] == 1,
      createdAt: json['created_at'] as String?,
      items: items,
    );
  }

  bool get isActive => status == 'validee';
}
