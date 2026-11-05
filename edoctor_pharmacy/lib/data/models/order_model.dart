class OrderItemModel {
  final int id;
  final int medicationId;
  final String medicationName;
  final int quantity;
  final double unitPrice;

  const OrderItemModel({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final med = json['medication'] as Map<String, dynamic>? ?? {};
    return OrderItemModel(
      id: json['id'] as int? ?? 0,
      medicationId: json['medication_id'] as int? ?? 0,
      medicationName: (med['name'] as String?) ?? (json['medication_name'] as String? ?? 'Médicament'),
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class OrderModel {
  final int id;
  final int patientId;
  final String patientName;
  final String? patientPhone;
  final String? patientEmail;
  final String? patientAddress;
  final int pharmacyId;
  final int? prescriptionId;
  final String status;
  final double totalAmount;
  final double itemsAmount;
  final double deliveryFee;
  final bool hasDelivery;
  final int? deliveryId;
  final String? deliveryAddress;
  final String? courierName;
  final String? deliveryStatus;
  final String createdAt;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.patientEmail,
    this.patientAddress,
    required this.pharmacyId,
    this.prescriptionId,
    required this.status,
    required this.totalAmount,
    this.itemsAmount = 0.0,
    this.deliveryFee = 0.0,
    this.hasDelivery = false,
    this.deliveryId,
    this.deliveryAddress,
    this.courierName,
    this.deliveryStatus,
    required this.createdAt,
    this.items = const [],
  });

  /// Commande à préparer : confirmée suite au paiement client ou en cours de préparation
  bool get isPending =>
      status == 'confirmee' ||
      status == 'en_attente' ||
      status == 'en_preparation';

  bool get isReady => status == 'prete';

  bool get isCompleted =>
      status == 'recuperee' ||
      status == 'collectee' ||
      status == 'livree';

  bool get isCancelled => status == 'annulee';
  bool get isDelivery => hasDelivery || deliveryId != null;
  bool get isEnRoute => status == 'en_livraison' || deliveryStatus == 'en_route';

  /// Adresse à afficher : adresse de livraison si renseignée, sinon adresse résidentielle du patient
  String? get displayAddress {
    if (isDelivery) {
      if (deliveryAddress != null && deliveryAddress!.trim().isNotEmpty) {
        return deliveryAddress!.trim();
      }
      return patientAddress?.trim();
    }
    if (patientAddress != null && patientAddress!.trim().isNotEmpty) {
      return patientAddress!.trim();
    }
    return deliveryAddress?.trim();
  }

  String get statusLabel {
    switch (status) {
      case 'confirmee':
        return 'Confirmée (À préparer)';
      case 'en_attente':
        return 'En attente';
      case 'en_preparation':
        return 'En préparation';
      case 'prete':
        return isDelivery ? 'Prête (à expédier)' : 'Prête au comptoir';
      case 'en_livraison':
        return 'En cours de livraison';
      case 'livree':
        return 'Livrée à domicile';
      case 'collectee':
      case 'recuperee':
        return 'Récupérée au comptoir';
      case 'annulee':
        return 'Annulée';
      default:
        return status;
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final p = json['patient'] as Map<String, dynamic>? ?? {};
    final del = json['delivery'] as Map<String, dynamic>?;
    final itemsList = (json['items'] as List?) ?? [];
    final total = double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0;
    final itemsAmt = double.tryParse(json['items_amount']?.toString() ?? '0') ?? total;
    final delFee = double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0.0;

    final pName = (p['name'] as String?)?.trim();
    final patientId = json['patient_id'] as int? ?? (p['id'] as int? ?? 0);

    return OrderModel(
      id: json['id'] as int? ?? 0,
      patientId: patientId,
      patientName: (pName != null && pName.isNotEmpty) ? pName : 'Patient #$patientId',
      patientPhone: (p['phone'] as String?)?.trim(),
      patientEmail: (p['email'] as String?)?.trim(),
      patientAddress: (p['address'] as String?)?.trim(),
      pharmacyId: json['pharmacy_id'] as int? ?? 0,
      prescriptionId: json['prescription_id'] as int?,
      status: json['status'] as String? ?? 'confirmee',
      totalAmount: total,
      itemsAmount: itemsAmt > 0 ? itemsAmt : total,
      deliveryFee: delFee,
      hasDelivery: del != null,
      deliveryId: del?['id'] as int?,
      deliveryAddress: del?['address'] as String?,
      courierName: del?['courier_name'] as String?,
      deliveryStatus: del?['status'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      items: itemsList.map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}
