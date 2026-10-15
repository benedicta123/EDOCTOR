class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? specialty;
  final String? licenseNumber;
  final int? hospitalId;
  final String? hospitalName;
  final String? pharmacyName;
  final bool isSuspended;
  final String? suspensionReason;
  final DateTime? suspendedAt;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.specialty,
    this.licenseNumber,
    this.hospitalId,
    this.hospitalName,
    this.pharmacyName,
    this.isSuspended = false,
    this.suspensionReason,
    this.suspendedAt,
    this.lastSeenAt,
    this.createdAt,
  });

  bool get isSuperAdmin => role == 'admin' && hospitalId == null;
  bool get isDoctor => role == 'doctor';
  bool get isPharmacist => role == 'pharmacist';
  bool get isNurse => role == 'nurse';
  bool get isPatient => role == 'patient';
  bool get isHospitalAdmin => role == 'admin' && hospitalId != null;

  String get roleLabel {
    switch (role) {
      case 'admin':
        return hospitalId == null ? 'Super-Admin' : 'Admin Hôpital';
      case 'doctor':
        return 'Médecin';
      case 'pharmacist':
        return 'Pharmacien';
      case 'nurse':
        return 'Infirmier(ère)';
      case 'patient':
        return 'Patient';
      default:
        return role;
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      phone: json['phone'] as String?,
      specialty: json['specialty'] as String?,
      licenseNumber: json['license_number'] as String?,
      hospitalId: json['hospital_id'] as int?,
      hospitalName: json['hospital'] != null ? json['hospital']['name'] as String? : null,
      pharmacyName: json['pharmacy'] != null ? json['pharmacy']['name'] as String? : null,
      isSuspended: json['is_suspended'] == true || json['is_suspended'] == 1,
      suspensionReason: json['suspension_reason'] as String?,
      suspendedAt: json['suspended_at'] != null ? DateTime.tryParse(json['suspended_at'] as String) : null,
      lastSeenAt: json['last_seen_at'] != null ? DateTime.tryParse(json['last_seen_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'phone': phone,
    'specialty': specialty,
    'license_number': licenseNumber,
    'hospital_id': hospitalId,
    'is_suspended': isSuspended,
    'suspension_reason': suspensionReason,
    'suspended_at': suspendedAt?.toIso8601String(),
  };
}
