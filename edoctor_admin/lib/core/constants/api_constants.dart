/// Endpoints de l'API Laravel pour le portail Super-Admin eDoctor
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const String desktopBaseUrl = 'http://127.0.0.1:8000/api';

  // Authentification & profil Super-Admin
  static const String login = '/login';
  static const String loginVerify2Fa = '/login/verify-2fa';
  static const String logout = '/logout';
  static const String me = '/me';
  static const String heartbeat = '/heartbeat';

  // Vue d'ensemble opérationnelle
  static const String adminOverview = '/admin/overview';

  // Module Hôpitaux Partenaires & Accréditation
  static const String adminHospitals = '/admin/hospitals';
  static String adminHospitalVerify(int id) => '/admin/hospitals/$id/verify';
  static String adminHospitalReject(int id) => '/admin/hospitals/$id/reject';
  static String adminHospitalSuspend(int id) => '/admin/hospitals/$id/suspend';
  static String adminHospitalReactivate(int id) => '/admin/hospitals/$id/reactivate';

  // Module Pharmacies Partenaires & Agrément KYP
  static const String adminPharmacies = '/admin/pharmacies';
  static String adminPharmacyVerify(int id) => '/admin/pharmacies/$id/verify';
  static String adminPharmacyReject(int id) => '/admin/pharmacies/$id/reject';
  static String adminPharmacySuspend(int id) => '/admin/pharmacies/$id/suspend';
  static String adminPharmacyReactivate(int id) => '/admin/pharmacies/$id/reactivate';

  // Gestion des Utilisateurs & Modération
  static const String adminUsers = '/admin/users';
  static String adminUserSuspend(int id) => '/admin/users/$id/suspend';
  static String adminUserReactivate(int id) => '/admin/users/$id/reactivate';

  // Journal des Réclamations & Litiges
  static const String adminClaims = '/admin/claims';
  static String adminClaimResolve(int id) => '/admin/claims/$id/resolve';
  static String adminClaimStatus(int id) => '/admin/claims/$id/status';
}
