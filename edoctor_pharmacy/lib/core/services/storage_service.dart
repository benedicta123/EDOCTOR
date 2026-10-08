import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../data/models/pharmacy_model.dart';

class StorageService {
  StorageService._();

  static const String _keyToken = 'edoctor_pharma_token';
  static const String _keyUser = 'edoctor_pharma_user';
  static const String _keyPharmacy = 'edoctor_pharma_pharmacy';

  static Future<void> saveSession({
    required String token,
    required UserModel user,
    PharmacyModel? pharmacy,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    if (pharmacy != null) {
      await prefs.setString(_keyPharmacy, jsonEncode(pharmacy.toJson()));
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUser);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<PharmacyModel?> getPharmacy() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPharmacy);
    if (raw == null) return null;
    try {
      return PharmacyModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePharmacy(PharmacyModel pharmacy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPharmacy, jsonEncode(pharmacy.toJson()));
  }

  static const String _keyPendingApp = 'edoctor_pharma_pending_app';

  static Future<void> savePendingApplication({
    required String pharmacyName,
    required String pharmacistName,
    required String orderNumber,
    required String referenceId,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyPendingApp,
      jsonEncode({
        'pharmacyName': pharmacyName,
        'pharmacistName': pharmacistName,
        'orderNumber': orderNumber,
        'referenceId': referenceId,
        'email': email,
        'submittedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      }),
    );
  }

  static Future<Map<String, dynamic>?> getPendingApplication() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPendingApp);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updatePendingApplicationStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    final app = await getPendingApplication();
    if (app != null) {
      app['status'] = status;
      await prefs.setString(_keyPendingApp, jsonEncode(app));
    }
  }

  static Future<void> clearPendingApplication() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingApp);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyPharmacy);
  }
}
