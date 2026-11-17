import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_android/local_auth_android.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _keyBiometricEnabled = 'biometric_auth_enabled';

  /// Vérifie si l'appareil dispose du matériel biométrique et s'il est supporté
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
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

  /// Vérifie si une empreinte ou biométrie est déjà enregistrée/enrôlée sur l'appareil
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
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

  /// Déclenche l'authentification biométrique stricte (Empreinte digitale / Touch ID / Face ID)
  /// `biometricOnly: true` garantit qu'on vérifie uniquement l'empreinte/le visage
  static Future<bool> authenticateBiometricsOnly({
    String localizedReason =
        'Veuillez poser votre doigt sur le capteur d\'empreinte pour déverrouiller votre session eDoctor.',
  }) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Déverrouillage par Empreinte',
            signInHint: 'Touchez le capteur d\'empreinte pour continuer',
            cancelButton: 'Annuler',
          ),
          IOSAuthMessages(
            cancelButton: 'Annuler',
          ),
        ],
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometric auth platform error: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  /// Déclenche l'authentification par Code PIN / Schéma / Mot de passe du téléphone
  /// `biometricOnly: false` permet à Android/iOS de proposer et valider le code PIN de l'appareil
  static Future<bool> authenticateDevicePin({
    String localizedReason =
        'Veuillez saisir le code PIN ou schéma de votre téléphone pour déverrouiller votre session eDoctor.',
  }) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Déverrouillage par Code PIN',
            signInHint: 'Entrez le code PIN ou schéma de votre téléphone',
            cancelButton: 'Annuler',
          ),
          IOSAuthMessages(
            cancelButton: 'Annuler',
          ),
        ],
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Device PIN auth platform error: $e');
      return false;
    } catch (e) {
      debugPrint('Device PIN auth error: $e');
      return false;
    }
  }

  /// Méthode d'authentification générale (compatibilité)
  static Future<bool> authenticate({
    String localizedReason =
        'Veuillez confirmer votre identité pour accéder à votre dossier médical eDoctor.',
  }) async {
    return authenticateDevicePin(localizedReason: localizedReason);
  }
}
