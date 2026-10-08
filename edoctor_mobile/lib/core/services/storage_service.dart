import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user';
  static const String _keyServerUrl = 'server_base_url';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );

  /// Sauvegarde sécurisée de la session (Token et profil médical chiffrés avec Android Keystore / iOS Keychain)
  static Future<void> saveSession({
    required String token,
    required UserModel user,
  }) async {
    await _secureStorage.write(key: _keyToken, value: token);
    await _secureStorage.write(key: _keyUser, value: jsonEncode(user.toJson()));

    // Nettoyage de l'ancien stockage non chiffré si présent
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
    } catch (_) {}
  }

  /// Récupère le Token JWT chiffré (avec migration transparente si l'ancien existait dans SharedPreferences)
  static Future<String?> getToken() async {
    try {
      final secureToken = await _secureStorage.read(key: _keyToken);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (_) {}

    // Migration transparente depuis SharedPreferences pour les sessions déjà ouvertes
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_keyToken);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.write(key: _keyToken, value: legacyToken);
      await prefs.remove(_keyToken);
      return legacyToken;
    }
    return null;
  }

  /// Récupère le profil utilisateur chiffré (avec migration transparente)
  static Future<UserModel?> getUser() async {
    String? userJson;
    try {
      userJson = await _secureStorage.read(key: _keyUser);
    } catch (_) {}

    if (userJson == null || userJson.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      userJson = prefs.getString(_keyUser);
      if (userJson != null && userJson.isNotEmpty) {
        await _secureStorage.write(key: _keyUser, value: userJson);
        await prefs.remove(_keyUser);
      }
    }

    if (userJson == null || userJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl);
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url.trim());
  }

  /// Réinitialise la session en supprimant les données sécurisées et résiduelles
  static Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _keyToken);
      await _secureStorage.delete(key: _keyUser);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }
}
