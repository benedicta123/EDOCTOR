/// URLs et endpoints de l'API Laravel eDoctor
class ApiConstants {
  ApiConstants._();

  // URL de base paramétrable (10.0.2.2 pour émulateur Android, 127.0.0.1 pour web/desktop)
  // 192.168.1.139 = IP LAN actuelle du PC pour téléphone physique en Wi-Fi / USB
  static const String baseUrl = 'http://192.168.1.139:8000/api';
  static const String desktopBaseUrl = 'http://127.0.0.1:8000/api';

  // Authentification
  static const String register = '/register';
  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';
  static const String heartbeat = '/heartbeat';

  // Médecins & Consultations
  static const String availableDoctors = '/doctors/available';
  static const String consultations = '/consultations';
  static String consultationPay(int id) => '/consultations/$id/pay';
  static const String prescriptions = '/prescriptions';
  static const String orders = '/orders';
  static const String ordersQuote = '/orders/quote';
  static const String deliveriesQuote = '/deliveries/quote';
  static const String pharmacies = '/pharmacies';
  static const String notifications = '/notifications';
  static const String claims = '/claims';
  static const String myClaims = '/claims/my';

  // Bilans et examens complémentaires
  static const String labRequestsMy = '/lab-requests/my';
  static String consultationLabRequests(int consultationId) =>
      '/consultations/$consultationId/lab-requests';
  static String labRequestDetails(int id) => '/lab-requests/$id';
  static String labRequestResults(int id) => '/lab-requests/$id/results';
}
