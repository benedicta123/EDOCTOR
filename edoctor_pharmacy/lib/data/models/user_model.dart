class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final int? pharmacyId;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.pharmacyId,
  });

  bool get isPharmacist => role == 'pharmacist' || role == 'pharmacy' || role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String?,
      pharmacyId: json['pharmacy_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'phone': phone,
    'pharmacy_id': pharmacyId,
  };
}
