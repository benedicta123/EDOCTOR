class HospitalModel {
  final int id;
  final String name;
  final String status; // en_attente, verifie, rejete, suspendu
  final String? address;
  final String? phone;
  final String? officialEmail;
  final String? licenseNumber;
  final String? taxNumber;
  final String? licenseDocumentPath;
  final DateTime? verifiedAt;
  final String? rejectedReason;
  final int doctorsCount;
  final int staffCount;
  final List<dynamic>? admins;
  final DateTime? createdAt;

  HospitalModel({
    required this.id,
    required this.name,
    required this.status,
    this.address,
    this.phone,
    this.officialEmail,
    this.licenseNumber,
    this.taxNumber,
    this.licenseDocumentPath,
    this.verifiedAt,
    this.rejectedReason,
    this.doctorsCount = 0,
    this.staffCount = 0,
    this.admins,
    this.createdAt,
  });

  bool get isPending => status == 'en_attente';
  bool get isVerified => status == 'verifie';
  bool get isRejected => status == 'rejete';
  bool get isSuspended => status == 'suspendu';

  String get statusLabel {
    switch (status) {
      case 'verifie':
        return 'Partenaire Certifié';
      case 'en_attente':
        return 'En attente d\'audit';
      case 'rejete':
        return 'Dossier rejeté';
      case 'suspendu':
        return 'Partenariat suspendu';
      default:
        return status;
    }
  }

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    return HospitalModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'en_attente',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      officialEmail: json['official_email'] as String?,
      licenseNumber: json['license_number'] as String?,
      taxNumber: json['tax_number'] as String?,
      licenseDocumentPath: json['license_document_path'] as String?,
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'] as String) : null,
      rejectedReason: json['rejected_reason'] as String?,
      doctorsCount: json['doctors_count'] as int? ?? 0,
      staffCount: json['staff_count'] as int? ?? 0,
      admins: json['admins'] as List<dynamic>?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
