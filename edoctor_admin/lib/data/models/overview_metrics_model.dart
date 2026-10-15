import 'hospital_model.dart';
import 'pharmacy_model.dart';

class OverviewMetricsModel {
  // Consultations
  final int consultationsTotal;
  final int consultationsCompleted;
  final int consultationsInProgress;
  final int consultationsPending;
  final int consultationsCancelled;

  // Ordonnances
  final int prescriptionsTotal;

  // Finances (FCFA)
  final double revenueTotal;
  final double paymentsSum;
  final double ordersSum;
  final List<dynamic> paymentsByMethod;

  // Hôpitaux
  final int hospitalsTotal;
  final int hospitalsPending;
  final int hospitalsVerified;
  final int hospitalsRejected;
  final int hospitalsSuspended;

  // Pharmacies
  final int pharmaciesTotal;
  final int pharmaciesPending;
  final int pharmaciesVerified;
  final int pharmaciesRejected;
  final int pharmaciesSuspended;

  // Utilisateurs
  final int usersTotal;
  final int patientsCount;
  final int doctorsCount;
  final int pharmacistsCount;
  final int nursesCount;
  final int adminsCount;
  final int suspendedUsersCount;

  // Réclamations
  final int claimsTotal;
  final int claimsOpen;
  final int claimsInProgress;
  final int claimsResolved;

  // Listes récentes
  final List<dynamic> recentConsultations;
  final List<HospitalModel> pendingHospitals;
  final List<PharmacyModel> pendingPharmacies;

  OverviewMetricsModel({
    required this.consultationsTotal,
    required this.consultationsCompleted,
    required this.consultationsInProgress,
    required this.consultationsPending,
    required this.consultationsCancelled,
    required this.prescriptionsTotal,
    required this.revenueTotal,
    required this.paymentsSum,
    required this.ordersSum,
    required this.paymentsByMethod,
    required this.hospitalsTotal,
    required this.hospitalsPending,
    required this.hospitalsVerified,
    required this.hospitalsRejected,
    required this.hospitalsSuspended,
    required this.pharmaciesTotal,
    required this.pharmaciesPending,
    required this.pharmaciesVerified,
    required this.pharmaciesRejected,
    required this.pharmaciesSuspended,
    required this.usersTotal,
    required this.patientsCount,
    required this.doctorsCount,
    required this.pharmacistsCount,
    required this.nursesCount,
    required this.adminsCount,
    required this.suspendedUsersCount,
    required this.claimsTotal,
    required this.claimsOpen,
    required this.claimsInProgress,
    required this.claimsResolved,
    required this.recentConsultations,
    required this.pendingHospitals,
    required this.pendingPharmacies,
  });

  factory OverviewMetricsModel.fromJson(Map<String, dynamic> json) {
    final m = json['metrics'] as Map<String, dynamic>? ?? {};
    final r = json['recent'] as Map<String, dynamic>? ?? {};

    final cons = m['consultations'] as Map<String, dynamic>? ?? {};
    final presc = m['prescriptions'] as Map<String, dynamic>? ?? {};
    final rev = m['revenue'] as Map<String, dynamic>? ?? {};
    final hosp = m['hospitals'] as Map<String, dynamic>? ?? {};
    final pharm = m['pharmacies'] as Map<String, dynamic>? ?? {};
    final usr = m['users'] as Map<String, dynamic>? ?? {};
    final clm = m['claims'] as Map<String, dynamic>? ?? {};

    return OverviewMetricsModel(
      consultationsTotal: cons['total'] as int? ?? 0,
      consultationsCompleted: cons['completed'] as int? ?? 0,
      consultationsInProgress: cons['in_progress'] as int? ?? 0,
      consultationsPending: cons['pending'] as int? ?? 0,
      consultationsCancelled: cons['cancelled'] as int? ?? 0,
      prescriptionsTotal: presc['total'] as int? ?? 0,
      revenueTotal: (rev['total_fcfa'] as num?)?.toDouble() ?? 0.0,
      paymentsSum: (rev['payments_sum'] as num?)?.toDouble() ?? 0.0,
      ordersSum: (rev['orders_sum'] as num?)?.toDouble() ?? 0.0,
      paymentsByMethod: rev['by_method'] as List<dynamic>? ?? [],
      hospitalsTotal: hosp['total'] as int? ?? 0,
      hospitalsPending: hosp['pending'] as int? ?? 0,
      hospitalsVerified: hosp['verified'] as int? ?? 0,
      hospitalsRejected: hosp['rejected'] as int? ?? 0,
      hospitalsSuspended: hosp['suspended'] as int? ?? 0,
      pharmaciesTotal: pharm['total'] as int? ?? 0,
      pharmaciesPending: pharm['pending'] as int? ?? 0,
      pharmaciesVerified: pharm['verified'] as int? ?? 0,
      pharmaciesRejected: pharm['rejected'] as int? ?? 0,
      pharmaciesSuspended: pharm['suspended'] as int? ?? 0,
      usersTotal: usr['total'] as int? ?? 0,
      patientsCount: usr['patients'] as int? ?? 0,
      doctorsCount: usr['doctors'] as int? ?? 0,
      pharmacistsCount: usr['pharmacists'] as int? ?? 0,
      nursesCount: usr['nurses'] as int? ?? 0,
      adminsCount: usr['admins'] as int? ?? 0,
      suspendedUsersCount: usr['suspended'] as int? ?? 0,
      claimsTotal: clm['total'] as int? ?? 0,
      claimsOpen: clm['open'] as int? ?? 0,
      claimsInProgress: clm['in_progress'] as int? ?? 0,
      claimsResolved: clm['resolved'] as int? ?? 0,
      recentConsultations: r['consultations'] as List<dynamic>? ?? [],
      pendingHospitals: (r['pending_hospitals'] as List<dynamic>? ?? [])
          .map((e) => HospitalModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingPharmacies: (r['pending_pharmacies'] as List<dynamic>? ?? [])
          .map((e) => PharmacyModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
