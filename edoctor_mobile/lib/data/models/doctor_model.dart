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
    final cFee = (json['consultation_fee'] as num?)?.toDouble() ?? 3000.0;
    final eFee = (json['edoctor_fee'] as num?)?.toDouble() ?? 600.0;
    final tAmount = (json['total_amount'] as num?)?.toDouble() ?? (cFee + eFee);

    return DoctorModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Médecin',
      specialty: json['specialty'] as String? ?? 'Médecine Générale',
      hospitalName: hospital?['name'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewsCount: json['reviews_count'] as int? ?? 110,
      languages: json['languages'] as String? ?? 'Français, Éwé',
      avatarUrl: json['avatar_url'] as String?,
      isOnline: json['is_online'] as bool? ?? true,
      consultationFee: cFee,
      edoctorFee: eFee,
      totalAmount: tAmount,
    );
  }
}
