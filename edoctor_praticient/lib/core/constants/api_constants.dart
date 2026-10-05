/// URLs et endpoints de l'API Laravel eDoctor — espace Praticien
/// (médecins + administrateurs d'hôpital).
class ApiConstants {
  ApiConstants._();

  // PC dev : 127.0.0.1 pour web/desktop, IP LAN pour téléphone physique.
  // Aligne sur edoctor_mobile : même API Laravel sur :8000/api
  static const String baseUrl = 'http://192.168.1.139:8000/api';
  static const String desktopBaseUrl = 'http://127.0.0.1:8000/api';

  // Auth (POST /login universel : doctor + admin hopital)
  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';
  static const String profile = '/profile';
  static const String heartbeat = '/heartbeat';

  // Inscription hopital (cree Hospital + User admin)
  static const String hospitalRegister = '/hospitals/register';
  static const String hospitalGeocode = '/hospitals/geocode';

  // Medecin
  static const String doctorDashboard = '/doctor/dashboard';
  static const String doctorPatients = '/doctor/patients';
  static const String doctorProfile = '/doctor/profile';
  static const String doctorAvailability = '/doctor/availability';
  static const String consultations = '/consultations';
  static const String prescriptions = '/prescriptions';
  static const String medications = '/medications';
  static String consultationMedications(int id) => '/consultations/$id/medications';
  static String patientDossier(int patientId) => '/patients/$patientId/dossier';
  static String consultationMessages(int id) => '/consultations/$id/messages';
  static String consultationStart(int id) => '/consultations/$id/start';
  static String consultationDecline(int id) => '/consultations/$id/decline';
  static String consultationEnd(int id) => '/consultations/$id/end';
  static String consultationCancel(int id) => '/consultations/$id/cancel';
  static String prescriptionCancel(int id) => '/prescriptions/$id/cancel';
  static const String labRequestsMy = '/lab-requests/my';
  static String consultationLabRequests(int consultationId) =>
      '/consultations/$consultationId/lab-requests';
  static String labRequestDetails(int id) => '/lab-requests/$id';
  static String labRequestResults(int id) => '/lab-requests/$id/results';
  static String labRequestReview(int id) => '/lab-requests/$id/review';

  // Admin hopital
  static const String hospitalDashboard = '/my-hospital/dashboard';
  static const String hospitalConsultations = '/my-hospital/consultations';
  static const String hospitalStatistics = '/my-hospital/statistics';
  static const String myHospital = '/my-hospital';
  static const String myHospitalStaff = '/my-hospital/staff';
  static const String myHospitalDoctors = '/my-hospital/doctors';
  static const String myHospitalNurses = '/my-hospital/nurses';
  static String hospitalNurseVisits(int hospitalId) =>
      '/hospitals/$hospitalId/nurse-visits';
  static String nurseVisitAssign(int id) => '/nurse-visits/$id/assign';

  // Notifications
  static const String notifications = '/notifications';

  // Téléconsultation vidéo : Jitsi as a Service (8x8.vc).
  // Domaine + salle + JWT fournis par POST /consultations/{id}/join.
  // Aucune URL vidéo en dur côté client.
  static String consultationJoin(int id) => '/consultations/$id/join';
}
