import 'user_model.dart';

class HospitalModel {
  final int id;
  final String name;
  final String status; // en_attente | verifie | rejete | suspendu
  final String? address;
  final String? phone;
  final String? officialEmail;
  final String? licenseNumber;
  final String? latitude;
  final String? longitude;
  final String? verifiedAt;
  final List<UserModel> doctors;
  final List<UserModel> nurses;

  const HospitalModel({
    required this.id,
    required this.name,
    required this.status,
    this.address,
    this.phone,
    this.officialEmail,
    this.licenseNumber,
    this.latitude,
    this.longitude,
    this.verifiedAt,
    this.doctors = const [],
    this.nurses = const [],
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    List<UserModel> parse(String key) {
      final raw = json[key];
      if (raw is! List) return [];
      return raw
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return HospitalModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'en_attente',
      address: json['address'] as String?,
      phone: json['phone'] as String? ?? json['hospital_phone'] as String?,
      officialEmail: json['official_email'] as String?,
      licenseNumber: json['license_number'] as String?,
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      verifiedAt: json['verified_at'] as String?,
      doctors: parse('doctors'),
      nurses: parse('nurses'),
    );
  }
}
