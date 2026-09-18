/// URLs et endpoints de l'API Laravel eDoctor
class ApiConstants {
  ApiConstants._();

  // URL de base paramétrable (10.0.2.2 pour émulateur Android, 127.0.0.1 pour web/desktop)
  // 192.168.1.74 = IP LAN actuelle du PC pour téléphone physique en Wi-Fi / USB
  static const String baseUrl = 'http://192.168.1.74:8000/api';
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
  static const String prescriptions = '/prescriptions';
  static const String orders = '/orders';
  static const String notifications = '/notifications';
}
