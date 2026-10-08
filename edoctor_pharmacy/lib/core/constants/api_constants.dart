/// Endpoints REST pour le portail Officine / Pharmacie eDoctor
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://edoctor-api.ewaregroup.org/api';
  static const String desktopBaseUrl = 'https://edoctor-api.ewaregroup.org/api';

  // Authentification & profil
  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';
  static const String profile = '/profile';
  static const String heartbeat = '/heartbeat';

  // Pharmacie & Officine
  static const String myPharmacy = '/my-pharmacy';
  static String pharmacy(int id) => '/pharmacies/$id';
  static String pharmacyStocks(int id) => '/pharmacies/$id/stocks';
  static String pharmacyStocksImport(int id) => '/pharmacies/$id/stocks/import';
  static String pharmacyStocksExport(int id) => '/pharmacies/$id/stocks/export';
  static const String pharmacyStocksTemplate = '/pharmacies/stocks/template';
  static String pharmacyStock(int pharmacyId, int stockId) => '/pharmacies/$pharmacyId/stocks/$stockId';

  // Commandes & Ordonnances
  static const String orders = '/orders';
  static String order(int id) => '/orders/$id';
  static String orderMarkReady(int id) => '/orders/$id/mark-ready';
  static String orderMarkCollected(int id) => '/orders/$id/mark-collected';
  static String orderCancel(int id) => '/orders/$id/cancel';
  static String orderDelivery(int id) => '/orders/$id/delivery';

  // Catalogue Médicaments
  static const String medications = '/medications';
  static String medication(int id) => '/medications/$id';

  // Notifications
  static const String notifications = '/notifications';
  static String notificationRead(int id) => '/notifications/$id/read';
}
