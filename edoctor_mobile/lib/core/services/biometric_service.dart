import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _keyBiometricEnabled = 'biometric_auth_enabled';

  /// Vérifie si l'appareil dispose du matériel biométrique et s'il est configuré
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  /// Retourne les types de biométries disponibles (empreinte, visage, etc.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Vérifie si l'utilisateur a activé le verrouillage biométrique dans ses préférences
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Active ou désactive le verrouillage biométrique
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  /// Déclenche l'authentification biométrique native
  /// Retourne true si l'utilisateur a validé son empreinte/visage/code PIN
  static Future<bool> authenticate({
    String localizedReason = 'Veuillez confirmer votre empreinte ou visage pour accéder à votre dossier médical eDoctor.',
  }) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false, // Permet le repli sur le code PIN de l'appareil en cas de besoin
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
