import 'user_model.dart';

class PharmacyModel {
  final int id;
  final String? referenceId;
  final String name;
  final String status; // en_attente, verifie, rejete, suspendu
  final String? address;
  final String? phone;
  final String? officialEmail;
  final String? licenseNumber;
  final String? orderNumber;
  final String? taxNumber;
  final Map<String, dynamic>? documents;
  final DateTime? verifiedAt;
  final String? rejectedReason;
  final UserModel? owner;
  final int stocksCount;
  final DateTime? createdAt;

  PharmacyModel({
    required this.id,
    this.referenceId,
    required this.name,
    required this.status,
    this.address,
    this.phone,
    this.officialEmail,
    this.licenseNumber,
    this.orderNumber,
    this.taxNumber,
    this.documents,
    this.verifiedAt,
    this.rejectedReason,
    this.owner,
    this.stocksCount = 0,
    this.createdAt,
  });

  bool get isPending => status == 'en_attente';
  bool get isVerified => status == 'verifie';
  bool get isRejected => status == 'rejete';
  bool get isSuspended => status == 'suspendu';

  String get statusLabel {
    switch (status) {
      case 'verifie':
        return 'Officine Agréée eDoctor';
      case 'en_attente':
        return 'En attente de validation';
      case 'rejete':
        return 'Dossier rejeté';
      case 'suspendu':
        return 'Accès suspendu';
      default:
        return status;
    }
  }

  factory PharmacyModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? docs;
    if (json['documents'] != null) {
      if (json['documents'] is Map) {
        docs = Map<String, dynamic>.from(json['documents'] as Map);
      }
    }

    return PharmacyModel(
      id: json['id'] as int? ?? 0,
      referenceId: json['reference_id'] as String?,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'en_attente',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      officialEmail: json['official_email'] as String?,
      licenseNumber: json['license_number'] as String?,
      orderNumber: json['order_number'] as String?,
      taxNumber: json['tax_number'] as String?,
      documents: docs,
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'] as String) : null,
      rejectedReason: json['rejected_reason'] as String?,
      owner: json['owner'] != null ? UserModel.fromJson(json['owner'] as Map<String, dynamic>) : null,
      stocksCount: json['stocks'] != null && json['stocks'] is List ? (json['stocks'] as List).length : 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
