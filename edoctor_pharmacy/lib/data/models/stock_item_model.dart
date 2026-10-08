enum StockStatus {
  inStock,
  lowStock,
  outOfStock,
}

class StockItemModel {
  final int id;
  final int pharmacyId;
  final int medicationId;
  final String medicationName;
  final String? dosage;
  final String? form;
  final String? category;
  final bool requiresPrescription;
  final int quantity;
  final double price;
  final int alertThreshold;

  const StockItemModel({
    required this.id,
    required this.pharmacyId,
    required this.medicationId,
    required this.medicationName,
    this.dosage,
    this.form,
    this.category,
    this.requiresPrescription = false,
    required this.quantity,
    required this.price,
    this.alertThreshold = 10,
  });

  StockStatus get status {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= alertThreshold) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  String get statusLabel {
    switch (status) {
      case StockStatus.inStock:
        return 'En stock';
      case StockStatus.lowStock:
        return 'Stock faible';
      case StockStatus.outOfStock:
        return 'Rupture';
    }
  }

  factory StockItemModel.fromJson(Map<String, dynamic> json) {
    final med = json['medication'] as Map<String, dynamic>? ?? {};
    return StockItemModel(
      id: json['id'] as int? ?? 0,
      pharmacyId: json['pharmacy_id'] as int? ?? 0,
      medicationId: json['medication_id'] as int? ?? (med['id'] as int? ?? 0),
      medicationName: (med['name'] as String?) ?? (json['medication_name'] as String? ?? 'Médicament'),
      dosage: med['dosage'] as String?,
      form: med['form'] as String?,
      category: med['category'] as String?,
      requiresPrescription: med['requires_prescription'] as bool? ?? false,
      quantity: json['quantity'] as int? ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      alertThreshold: json['alert_threshold'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pharmacy_id': pharmacyId,
    'medication_id': medicationId,
    'quantity': quantity,
    'price': price,
  };
}
