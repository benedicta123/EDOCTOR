class LabRequestItemModel {
  final int id;
  final String name;
  final String category; // biologie, imagerie, parasitologie, bacteriologie, autre
  final String? instructions;

  const LabRequestItemModel({
    required this.id,
    required this.name,
    this.category = 'biologie',
    this.instructions,
  });

  factory LabRequestItemModel.fromJson(Map<String, dynamic> json) {
    return LabRequestItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Examen médical',
      category: json['category'] as String? ?? 'biologie',
      instructions: json['instructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        if (instructions != null && instructions!.isNotEmpty)
          'instructions': instructions,
      };
}

class LabRequestResultModel {
  final int id;
  final String filePath;
  final String fileName;
  final String? mimeType;
  final int? fileSize;
  final String? patientNotes;
  final String? uploaderName;
  final String? createdAt;

  const LabRequestResultModel({
    required this.id,
    required this.filePath,
    required this.fileName,
    this.mimeType,
    this.fileSize,
    this.patientNotes,
    this.uploaderName,
    this.createdAt,
  });

  bool get isPdf =>
      (mimeType != null && mimeType!.contains('pdf')) ||
      fileName.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      (mimeType != null && mimeType!.startsWith('image/')) ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.webp');

  String get formattedDate {
    if (createdAt == null) return 'Récemment';
    final dt = DateTime.tryParse(createdAt!);
    if (dt == null) return 'Récemment';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  factory LabRequestResultModel.fromJson(Map<String, dynamic> json) {
    final uploaderObj = json['uploader'] as Map<String, dynamic>?;
    return LabRequestResultModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      filePath: json['file_path'] as String? ?? '',
      fileName: json['file_name'] as String? ?? 'Document_analyse',
      mimeType: json['mime_type'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      patientNotes: json['patient_notes'] as String?,
      uploaderName: uploaderObj?['name'] as String? ?? 'Patient',
      createdAt: json['created_at'] as String?,
    );
  }
}

class LabRequestModel {
  final int id;
  final String referenceCode;
  final int consultationId;
  final String? consultationReferenceCode;
  final int doctorId;
  final int patientId;
  final String? clinicalNotes;
  final String urgencyLevel; // 'normal' | 'urgent'
  final bool fastingRequired;
  final String status; // 'prescrit' | 'en_attente_resultats' | 'resultats_recus' | 'analyse_terminee'
  final String? doctorReviewNotes;
  final String? resultsUploadedAt;
  final String? reviewedAt;
  final String? createdAt;
  final List<LabRequestItemModel> items;
  final List<LabRequestResultModel> results;

  final String patientName;
  final String patientAge;
  final String patientPhone;
  final String doctorName;
  final String doctorSpecialty;
  final String hospitalName;
  final String diagnosis;

  const LabRequestModel({
    required this.id,
    required this.referenceCode,
    required this.consultationId,
    this.consultationReferenceCode,
    required this.doctorId,
    required this.patientId,
    this.clinicalNotes,
    this.urgencyLevel = 'normal',
    this.fastingRequired = false,
    this.status = 'prescrit',
    this.doctorReviewNotes,
    this.resultsUploadedAt,
    this.reviewedAt,
    this.createdAt,
    this.items = const [],
    this.results = const [],
    this.patientName = 'Patient eDoctor',
    this.patientAge = 'Âge non spécifié',
    this.patientPhone = '',
    this.doctorName = 'Dr. Praticien',
    this.doctorSpecialty = 'Médecine Générale',
    this.hospitalName = 'Centre Hospitalier Partenaire',
    this.diagnosis = 'Non spécifié',
  });

  bool get isUrgent => urgencyLevel.toLowerCase() == 'urgent';
  bool get hasResults => results.isNotEmpty;

  String get statusDisplayLabel {
    switch (status) {
      case 'resultats_recus':
        return 'Résultats transmis au médecin';
      case 'analyse_terminee':
        return 'Analysé & Validé par le médecin';
      case 'en_attente_resultats':
        return 'En attente de vos résultats';
      case 'prescrit':
      default:
        return 'Prescription émise (Prélèvement à réaliser)';
    }
  }

  String get formattedDate {
    if (createdAt == null) return 'Récemment';
    final dt = DateTime.tryParse(createdAt!);
    if (dt == null) return 'Récemment';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  factory LabRequestModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List? ?? [])
        .map((e) => LabRequestItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final resultsList = (json['results'] as List? ?? [])
        .map((e) => LabRequestResultModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final patientObj = json['patient'] as Map<String, dynamic>?;
    final doctorObj = json['doctor'] as Map<String, dynamic>?;
    final consultationObj = json['consultation'] as Map<String, dynamic>?;
    final hospitalObj = doctorObj?['hospital'] as Map<String, dynamic>?;

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

    return LabRequestModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      referenceCode: json['reference_code'] as String? ?? 'LAB-${json['id']}',
      consultationId: (json['consultation_id'] as num?)?.toInt() ?? 0,
      consultationReferenceCode: consultationObj?['reference_code'] as String?,
      doctorId: (json['doctor_id'] as num?)?.toInt() ?? 0,
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      clinicalNotes: json['clinical_notes'] as String?,
      urgencyLevel: json['urgency_level'] as String? ?? 'normal',
      fastingRequired: json['fasting_required'] == true ||
          (json['fasting_required'] is num && (json['fasting_required'] as num) == 1),
      status: json['status'] as String? ?? 'prescrit',
      doctorReviewNotes: json['doctor_review_notes'] as String?,
      resultsUploadedAt: json['results_uploaded_at'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      createdAt: json['created_at'] as String?,
      items: itemsList,
      results: resultsList,
      patientName: patientObj?['name'] as String? ?? 'Patient eDoctor',
      patientAge: calculateAge(patientObj?['date_of_birth'] as String?),
      patientPhone: patientObj?['phone'] as String? ?? '',
      doctorName: doctorObj?['name'] as String? ?? 'Dr. Praticien',
      doctorSpecialty: doctorObj?['specialty'] as String? ?? 'Médecine Générale',
      hospitalName: hospitalObj?['name'] as String? ?? 'Centre Hospitalier Partenaire',
      diagnosis: consultationObj?['diagnosis'] as String? ?? 'Non spécifié',
    );
  }
}
