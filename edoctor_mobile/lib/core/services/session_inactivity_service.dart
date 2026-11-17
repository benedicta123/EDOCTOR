import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'biometric_service.dart';
import 'storage_service.dart';

/// Service de gestion du verrouillage automatique après inactivité.
/// Protège les données de santé du patient en exigeant une authentification
/// par empreinte digitale ou par le code PIN du téléphone après 30 minutes d'inactivité.
class SessionInactivityService {
  SessionInactivityService._();

  static const String _keyLastActivity = 'session_last_activity_time';

  /// Délai réglementaire de sécurité : 30 minutes
  static const Duration inactivityTimeout = Duration(minutes: 30);

  /// Notificateur d'état de verrouillage
  static final ValueNotifier<bool> isLockedNotifier = ValueNotifier<bool>(false);

  static Timer? _inactivityCheckerTimer;
  static bool _isAuthenticating = false;

  /// Initialise la surveillance d'inactivité
  static Future<void> init() async {
    // Vérification initiale
    await checkInactivity();

    // Surveillance périodique toutes les 30 secondes en tâche de fond de l'app
    _inactivityCheckerTimer?.cancel();
    _inactivityCheckerTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkInactivity(),
    );
  }

  /// Enregistre une interaction utilisateur (toucher, tap, défilement)
  static Future<void> recordActivity() async {
    // Ne pas rafraîchir l'inactivité si l'écran est déjà verrouillé
    if (isLockedNotifier.value) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastActivity, now);
    } catch (_) {}
  }

  /// Déclenché lorsque l'application passe en arrière-plan (mise en veille, changement d'application)
  static Future<void> onAppPaused() async {
    final token = await StorageService.getToken();
    if (token == null || token.isEmpty) return;
    await recordActivity();
  }

  /// Déclenché lorsque l'application revient au premier plan
  static Future<void> onAppResumed() async {
    // L'écran s'affiche pour laisser le patient choisir entre Empreinte et Code PIN
    await checkInactivity(triggerBiometricImmediately: false);
  }

  /// Vérifie si l'inactivité a dépassé 30 minutes
  static Future<void> checkInactivity({
    bool triggerBiometricImmediately = false,
  }) async {
    final token = await StorageService.getToken();
    // Aucun verrouillage si l'utilisateur n'est pas authentifié
    if (token == null || token.isEmpty) {
      if (isLockedNotifier.value) {
        isLockedNotifier.value = false;
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActivity = prefs.getInt(_keyLastActivity);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (lastActivity == null) {
        await prefs.setInt(_keyLastActivity, now);
        return;
      }

      final elapsed = Duration(milliseconds: now - lastActivity);
      if (elapsed >= inactivityTimeout) {
        if (!isLockedNotifier.value) {
          isLockedNotifier.value = true;
        }

        if (triggerBiometricImmediately) {
          await authenticateWithBiometrics();
        }
      }
    } catch (e) {
      debugPrint('SessionInactivity check error: $e');
    }
  }

  /// Déverrouillage par Empreinte digitale (Biométrie stricte)
  static Future<bool> authenticateWithBiometrics() async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    try {
      final authenticated = await BiometricService.authenticateBiometricsOnly(
        localizedReason:
            'Session suspendue après 30 min d\'inactivité. Veuillez poser votre doigt sur le capteur d\'empreinte pour déverrouiller votre session eDoctor.',
      );

      if (authenticated) {
        isLockedNotifier.value = false;
        await recordActivity();
        return true;
      }
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Déverrouillage par Code PIN / Schéma du téléphone
  static Future<bool> authenticateWithPin() async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;
    try {
      final authenticated = await BiometricService.authenticateDevicePin(
        localizedReason:
            'Session suspendue après 30 min d\'inactivité. Veuillez entrer le code PIN ou schéma de votre téléphone pour déverrouiller votre session eDoctor.',
      );

      if (authenticated) {
        isLockedNotifier.value = false;
        await recordActivity();
        return true;
      }
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Déclenche l'authentification native par défaut (pour compatibilité)
  static Future<bool> authenticateAndUnlock() async {
    return authenticateWithBiometrics();
  }

  /// Déverrouillage manuel (par exemple après reconnexion explicite)
  static Future<void> unlockManually() async {
    isLockedNotifier.value = false;
    await recordActivity();
  }

  /// Réinitialise l'état d'inactivité (par exemple lors de la déconnexion)
  static Future<void> reset() async {
    isLockedNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastActivity);
    } catch (_) {}
  }
}
