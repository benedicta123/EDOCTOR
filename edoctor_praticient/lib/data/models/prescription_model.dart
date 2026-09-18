class MedicationModel {
  final int id;
  final String name;
  final String? dosage;
  final String? form;

  const MedicationModel(
      {required this.id, required this.name, this.dosage, this.form});

  factory MedicationModel.fromJson(Map<String, dynamic> json) =>
      MedicationModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ??
            (json['commercial_name'] as String?) ??
            'Medicament ${json['id']}',
        dosage: json['dosage'] as String?,
        form: json['form'] as String? ?? json['dosage_form'] as String?,
      );
}

class PrescriptionItemModel {
  final int? medicationId;
  final String medicationName;
  final String dosageInstructions;
  final int quantity;

  const PrescriptionItemModel({
    this.medicationId,
    required this.medicationName,
    required this.dosageInstructions,
    required this.quantity,
  });

  factory PrescriptionItemModel.fromJson(Map<String, dynamic> json) {
    final med = json['medication'] as Map<String, dynamic>?;
    return PrescriptionItemModel(
      medicationId: (json['medication_id'] as num?)?.toInt(),
      medicationName: med?['name'] as String? ??
          med?['commercial_name'] as String? ??
          'Medicament',
      dosageInstructions:
          json['dosage_instructions'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class PrescriptionModel {
  final int id;
  final int consultationId;
  final int doctorId;
  final int patientId;
  final String status; // validee | annulee
  final bool homeCareRecommended;
  final String patientName;
  final String doctorName;
  final List<PrescriptionItemModel> items;

  const PrescriptionModel({
    required this.id,
    required this.consultationId,
    required this.doctorId,
    required this.patientId,
    required this.status,
    this.homeCareRecommended = false,
    this.patientName = '',
    this.doctorName = '',
    this.items = const [],
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .map((e) => PrescriptionItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    String nested(String key) =>
        (json[key] as Map<String, dynamic>?)?['name'] as String? ?? '';
    return PrescriptionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      consultationId: (json['consultation_id'] as num?)?.toInt() ?? 0,
      doctorId: (json['doctor_id'] as num?)?.toInt() ?? 0,
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'validee',
      homeCareRecommended: json['home_care_recommended'] == true ||
          (json['home_care_recommended'] is num &&
              (json['home_care_recommended'] as num) == 1),
      patientName: nested('patient'),
      doctorName: nested('doctor'),
      items: items,
    );
  }
}
