class UserModel {
  final int id;
  final String name;
  final String email;
  final String role; // doctor | admin | nurse | patient
  final int? hospitalId;
  final String? phone;
  final String? specialty;
  final String? licenseNumber;
  final String? availabilityStatus;
  final String? dateOfBirth;
  final String? address;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.hospitalId,
    this.phone,
    this.specialty,
    this.licenseNumber,
    this.availabilityStatus,
    this.dateOfBirth,
    this.address,
  });

  bool get isDoctor => role == 'doctor';
  bool get isHospitalAdmin => role == 'admin' && hospitalId != null;
  bool get isSuperAdmin => role == 'admin' && hospitalId == null;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'doctor',
        hospitalId: (json['hospital_id'] as num?)?.toInt(),
        phone: json['phone'] as String?,
        specialty: json['specialty'] as String?,
        licenseNumber: json['license_number'] as String?,
        availabilityStatus: json['availability_status'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        address: json['address'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'hospital_id': hospitalId,
        'phone': phone,
        'specialty': specialty,
        'license_number': licenseNumber,
        'availability_status': availabilityStatus,
        'date_of_birth': dateOfBirth,
        'address': address,
      };
}
