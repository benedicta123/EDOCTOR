class DoctorModel {
  final int id;
  final String name;
  final String specialty;
  final String? hospitalName;
  final double rating;
  final int reviewsCount;
  final String languages;
  final String? avatarUrl;
  final bool isOnline;
  final double consultationFee;
  final double edoctorFee;
  final double totalAmount;

  const DoctorModel({
    required this.id,
    required this.name,
    required this.specialty,
    this.hospitalName,
    this.rating = 4.8,
    this.reviewsCount = 95,
    this.languages = 'Français, Éwé',
    this.avatarUrl,
    this.isOnline = true,
    this.consultationFee = 3000.0,
    this.edoctorFee = 600.0,
    this.totalAmount = 3600.0,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    final hospital = json['hospital'] as Map<String, dynamic>?;

    double parseDouble(dynamic v, [double fallback = 0.0]) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    int parseInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    final cFee = parseDouble(json['consultation_fee'], 3000.0);
    final eFee = parseDouble(json['edoctor_fee'], 300.0);
    final tAmount = parseDouble(json['total_amount'], cFee + eFee);

    return DoctorModel(
      id: parseInt(json['id']),
      name: json['name'] as String? ?? 'Médecin',
      specialty: json['specialty'] as String? ?? 'Médecine Générale',
      hospitalName: hospital?['name'] as String?,
      rating: parseDouble(json['rating'], 4.8),
      reviewsCount: parseInt(json['reviews_count'], 110),
      languages: json['languages'] as String? ?? 'Français, Éwé',
      avatarUrl: json['avatar_url'] as String?,
      isOnline: json['is_online'] as bool? ?? true,
      consultationFee: cFee,
      edoctorFee: eFee,
      totalAmount: tAmount,
    );
  }
}
