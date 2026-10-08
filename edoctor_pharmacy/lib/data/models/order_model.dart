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
  final int pharmacyId;
  final int? prescriptionId;
  final String status;
  final double totalAmount;
  final String createdAt;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    required this.pharmacyId,
    this.prescriptionId,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.items = const [],
  });

  bool get isPending => status == 'en_attente' || status == 'en_preparation';
  bool get isReady => status == 'prete';
  bool get isCompleted => status == 'recuperee' || status == 'livree';
  bool get isCancelled => status == 'annulee';

  String get statusLabel {
    switch (status) {
      case 'en_attente':
        return 'En attente';
      case 'en_preparation':
        return 'En préparation';
      case 'prete':
        return 'Prête à emporter';
      case 'en_livraison':
        return 'En livraison';
      case 'livree':
        return 'Livrée';
      case 'recuperee':
        return 'Récupérée';
      case 'annulee':
        return 'Annulée';
      default:
        return status;
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final p = json['patient'] as Map<String, dynamic>? ?? {};
    final itemsList = (json['items'] as List?) ?? [];
    return OrderModel(
      id: json['id'] as int? ?? 0,
      patientId: json['patient_id'] as int? ?? (p['id'] as int? ?? 0),
      patientName: (p['name'] as String?) ?? 'Patient #${json['patient_id'] ?? ''}',
      patientPhone: p['phone'] as String?,
      pharmacyId: json['pharmacy_id'] as int? ?? 0,
      prescriptionId: json['prescription_id'] as int?,
      status: json['status'] as String? ?? 'en_attente',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at'] as String? ?? '',
      items: itemsList.map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}
