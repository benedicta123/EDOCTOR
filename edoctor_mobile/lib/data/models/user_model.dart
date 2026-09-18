class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? dateOfBirth;
  final String? address;
  final String? medicalHistorySummary;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.dateOfBirth,
    this.address,
    this.medicalHistorySummary,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      phone: json['phone'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      address: json['address'] as String?,
      medicalHistorySummary: json['medical_history_summary'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'date_of_birth': dateOfBirth,
      'address': address,
      'medical_history_summary': medicalHistorySummary,
    };
  }
}
