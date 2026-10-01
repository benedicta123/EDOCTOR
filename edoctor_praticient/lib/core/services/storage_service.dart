import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';

/// Session locale : token Sanctum + user (role doctor / admin).
class StorageService {
  StorageService._();
  static const _keyToken = 'praticien_token';
  static const _keyUser = 'praticien_user';

  static Future<void> saveSession(
      {required String token, required UserModel user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
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

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  static Future<void> saveDraft(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_$key', jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('draft_$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearDraft(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('draft_$key');
  }
}
