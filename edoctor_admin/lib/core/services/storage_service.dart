import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';

class StorageService {
  StorageService._();

  static const String _keyToken = 'admin_auth_token';
  static const String _keyUser = 'admin_auth_user';

  static Future<void> saveSession({required String token, required UserModel user}) async {
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
    final str = prefs.getString(_keyUser);
    if (str == null) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
