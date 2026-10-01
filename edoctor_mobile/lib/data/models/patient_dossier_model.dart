import '../models/user_model.dart';

/// Dossier patient dérivé à 100% de l'API réelle :
/// GET /api/patients/{id}/dossier -> { patient, consultations, prescriptions }
/// Aucune valeur inventée : tout champ absent s'affiche "Non renseigné".
class DossierConsultation {
  final int id;
  final String referenceCode;
  final String status;
  final String? scheduledAt;
  final String? startedAt;
  final String? endedAt;
  final String? createdAt;
  final String doctorName;
  final String? doctorSpecialty;

  const DossierConsultation({
    required this.id,
    this.referenceCode = '',
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    required this.doctorName,
    this.doctorSpecialty,
  });

  String get displayCode => referenceCode.isNotEmpty ? referenceCode : '#$id';

  factory DossierConsultation.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'] as Map<String, dynamic>?;
    return DossierConsultation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      referenceCode: (json['reference_code'] as String? ?? '').trim(),
      status: json['status']?.toString() ?? '—',
      scheduledAt: json['scheduled_at']?.toString() ?? json['created_at']?.toString(),
      startedAt: json['started_at']?.toString(),
      endedAt: json['ended_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      doctorName: doctor?['name']?.toString() ?? 'Médecin eDoctor',
      doctorSpecialty: doctor?['specialty']?.toString(),
    );
  }

  /// Date de référence : début effectif, sinon planifiée, sinon création.
  String get referenceRaw => startedAt ?? scheduledAt ?? createdAt ?? '';

  /// Clé de tri chronologique (ancien → récent).
  String get sortKey => referenceRaw;

  String _format(bool withTime) {
    final raw = referenceRaw;
    if (raw.isEmpty) return 'Date non renseignée';
    // ISO "2026-09-04T10:30:00.000000Z" -> "04/09/2026"
    try {
      final dt = DateTime.parse(raw).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      if (!withTime) return '$d/$m/${dt.year}';
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/${dt.year} à $h:$min';
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  String get displayDate => _format(false);

  String get displayDateTime => _format(true);
}

class DossierPrescriptionItem {
  final String medicationName;
  final String? dosage;
  final int? quantity;

  const DossierPrescriptionItem({
    required this.medicationName,
    this.dosage,
    this.quantity,
  });

  factory DossierPrescriptionItem.fromJson(Map<String, dynamic> json) {
    final med = json['medication'] as Map<String, dynamic>?;
    return DossierPrescriptionItem(
      medicationName: med?['name']?.toString() ??
          json['medication_name']?.toString() ??
          'Médicament #${json['medication_id'] ?? '—'}',
      dosage: json['dosage_instructions']?.toString() ?? json['dosage']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt(),
    );
  }
}

class DossierPrescription {
  final int id;
  final int? consultationId;
  final String status;
  final String? createdAt;
  final String doctorName;
  final List<DossierPrescriptionItem> items;

  const DossierPrescription({
    required this.id,
    this.consultationId,
    required this.status,
    this.createdAt,
    required this.doctorName,
    required this.items,
  });

  factory DossierPrescription.fromJson(Map<String, dynamic> json) {
    final doctor = json['doctor'] as Map<String, dynamic>?;
    final rawItems = json['items'] as List? ?? const [];
    return DossierPrescription(
      id: (json['id'] as num?)?.toInt() ?? 0,
      consultationId: (json['consultation_id'] as num?)?.toInt(),
      status: json['status']?.toString() ?? '—',
      createdAt: json['created_at']?.toString(),
      doctorName: doctor?['name']?.toString() ?? 'Médecin eDoctor',
      items: rawItems
          .map((e) => DossierPrescriptionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get displayDate {
    final raw = createdAt ?? '';
    if (raw.isEmpty) return 'Date non renseignée';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/${dt.year} à $h:$min';
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }
}

class PatientDossier {
  final UserModel patient;
  final List<DossierConsultation> consultations;
  final List<DossierPrescription> prescriptions;

  const PatientDossier({
    required this.patient,
    required this.consultations,
    required this.prescriptions,
  });

  factory PatientDossier.fromJson(Map<String, dynamic> json) {
    final patientJson = json['patient'] as Map<String, dynamic>? ?? const {};
    // L'API ne renvoie qu'un sous-ensemble patient ; on complète avec la session si besoin.
    final rawList = json['consultations'] as List? ?? const [];
    final rawPresc = json['prescriptions'] as List? ?? const [];
    return PatientDossier(
      patient: UserModel.fromJson({
        'id': patientJson['id'] ?? 0,
        'name': patientJson['name'] ?? '',
        'email': patientJson['email'] ?? '',
        'role': 'patient',
        'phone': patientJson['phone'],
        'date_of_birth': patientJson['date_of_birth']?.toString(),
        'address': patientJson['address']?.toString(),
        'medical_history_summary':
            patientJson['medical_history_summary']?.toString(),
      }),
      consultations: rawList
          .map((e) => DossierConsultation.fromJson(e as Map<String, dynamic>))
          .toList(),
      prescriptions: rawPresc
          .map((e) => DossierPrescription.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Dernier médecin ayant réellement suivi le patient (dérivé, jamais inventé).
  String? get referringDoctor {
    if (consultations.isEmpty) return null;
    return consultations.first.doctorName;
  }
}
