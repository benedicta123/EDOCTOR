class PharmacyModel {
  final int id;
  final int ownerId;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String phone;
  final Map<String, dynamic>? openingHours;
  final bool isDuty; // Pharmacie de garde
  final String status; // 'en_attente' | 'verifie' | 'rejete'
  final String? referenceId;
  final String? licenseNumber;
  final String? orderNumber;
  final String? officialEmail;

  const PharmacyModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    required this.phone,
    this.openingHours,
    this.isDuty = false,
    this.status = 'verifie',
    this.referenceId,
    this.licenseNumber,
    this.orderNumber,
    this.officialEmail,
  });

  bool get isVerified => status == 'verifie';
  bool get isPending => status == 'en_attente';
  bool get isRejected => status == 'rejete';

  factory PharmacyModel.fromJson(Map<String, dynamic> json) {
    return PharmacyModel(
      id: json['id'] as int? ?? 0,
      ownerId: json['owner_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Pharmacie',
      address: json['address'] as String? ?? '',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      phone: json['phone'] as String? ?? '',
      openingHours: json['opening_hours'] as Map<String, dynamic>?,
      isDuty: json['is_duty'] as bool? ?? false,
      status: json['status'] as String? ?? 'verifie',
      referenceId: json['reference_id'] as String?,
      licenseNumber: json['license_number'] as String?,
      orderNumber: json['order_number'] as String?,
      officialEmail: json['official_email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'phone': phone,
    'opening_hours': openingHours,
    'is_duty': isDuty,
    'status': status,
    'reference_id': referenceId,
    'license_number': licenseNumber,
    'order_number': orderNumber,
    'official_email': officialEmail,
  };
}
