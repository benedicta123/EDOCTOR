class MedicationModel {
  final int id;
  final String name;
  final String? dosage;
  final String? form;
  final bool inStock;
  final int nearbyPharmaciesCount;
  final String? nearestPharmacy;
  final double? nearestDistanceKm;
  final double? minPrice;
  final double? maxPrice;

  const MedicationModel({
    required this.id,
    required this.name,
    this.dosage,
    this.form,
    this.inStock = true,
    this.nearbyPharmaciesCount = 0,
    this.nearestPharmacy,
    this.nearestDistanceKm,
    this.minPrice,
    this.maxPrice,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) =>
      MedicationModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ??
            (json['commercial_name'] as String?) ??
            'Medicament ${json['id']}',
        dosage: json['dosage'] as String?,
        form: json['form'] as String? ?? json['dosage_form'] as String?,
        inStock: json['in_stock'] == true || (json['in_stock'] is num && (json['in_stock'] as num) == 1),
        nearbyPharmaciesCount: (json['nearby_pharmacies_count'] as num?)?.toInt() ?? 0,
        nearestPharmacy: json['nearest_pharmacy'] as String?,
        nearestDistanceKm: (json['nearest_distance_km'] as num?)?.toDouble(),
        minPrice: (json['min_price'] as num?)?.toDouble(),
        maxPrice: (json['max_price'] as num?)?.toDouble(),
      );

  String get displayName {
    final buffer = StringBuffer(name);
    if (dosage != null && dosage!.isNotEmpty) buffer.write(' $dosage');
    if (form != null && form!.isNotEmpty) buffer.write(' ($form)');
    return buffer.toString();
  }

  String get stockLabel {
    if (inStock) {
      if (nearbyPharmaciesCount > 1) {
        return 'En stock ($nearbyPharmaciesCount pharmacies proches)';
      } else if (nearbyPharmaciesCount == 1) {
        return nearestPharmacy != null
            ? 'En stock ($nearestPharmacy)'
            : 'En stock (1 pharmacie proche)';
      }
      return 'En stock';
    }
    return 'Non détecté en stock';
  }
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
  final String? consultationReferenceCode;
  final int doctorId;
  final int patientId;
  final String status; // validee | annulee
  final bool homeCareRecommended;
  final String patientName;
  final String patientAge;
  final String patientPhone;
  final String doctorName;
  final String hospitalName;
  final String diagnosis;
  final String? createdAt;
  final List<PrescriptionItemModel> items;

  const PrescriptionModel({
    required this.id,
    required this.consultationId,
    this.consultationReferenceCode,
    required this.doctorId,
    required this.patientId,
    required this.status,
    this.homeCareRecommended = false,
    this.patientName = '',
    this.patientAge = 'Âge non spécifié',
    this.patientPhone = '',
    this.doctorName = '',
    this.hospitalName = 'Centre Hospitalier Partenaire',
    this.diagnosis = 'Non spécifié',
    this.createdAt,
    this.items = const [],
  });

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

  /// Règle médico-légale : l'ordonnance ne peut être annulée que dans les 5 minutes suivant son émission
  bool get canBeCancelled {
    if (status != 'validee' || createdAt == null) return false;
    final dt = DateTime.tryParse(createdAt!);
    if (dt == null) return false;
    return DateTime.now().difference(dt).inMinutes < 5;
  }

  int get minutesRemainingToCancel {
    if (createdAt == null) return 0;
    final dt = DateTime.tryParse(createdAt!);
    if (dt == null) return 0;
    final diff = DateTime.now().difference(dt).inMinutes;
    final remaining = 5 - diff;
    return remaining > 0 ? remaining : 0;
  }


  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .map((e) => PrescriptionItemModel.fromJson(e as Map<String, dynamic>))
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

    return PrescriptionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      consultationId: (json['consultation_id'] as num?)?.toInt() ?? 0,
      consultationReferenceCode: consultationObj?['reference_code'] as String?,
      doctorId: (json['doctor_id'] as num?)?.toInt() ?? 0,
      patientId: (json['patient_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'validee',
      homeCareRecommended: json['home_care_recommended'] == true ||
          (json['home_care_recommended'] is num &&
              (json['home_care_recommended'] as num) == 1),
      patientName: patientObj?['name'] as String? ?? (json['patient_name'] as String? ?? 'Patient eDoctor'),
      patientAge: calculateAge(patientObj?['date_of_birth'] as String?),
      patientPhone: patientObj?['phone'] as String? ?? '',
      doctorName: doctorObj?['name'] as String? ?? (json['doctor_name'] as String? ?? 'Dr. Praticien'),
      hospitalName: hospitalObj?['name'] as String? ?? 'Centre Hospitalier Universitaire de Démo',
      diagnosis: consultationObj?['diagnosis'] as String? ?? (json['diagnosis'] as String? ?? 'Non spécifié'),
      createdAt: json['created_at'] as String?,
      items: items,
    );
  }
}
