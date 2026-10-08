import 'package:flutter/material.dart';

/// Clé globale de navigation pour le portail Pharmacie — permet à ApiService
/// de rediriger automatiquement vers /login en cas de token expiré (401),
/// sans dépendre du BuildContext d'un écran particulier.
final GlobalKey<NavigatorState> pharmacyNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'edoctor_pharmacy_root');

/// Redirige vers l'écran de connexion et vide la pile de navigation.
void redirectToLogin() {
  final nav = pharmacyNavigatorKey.currentState;
  nav?.pushNamedAndRemoveUntil('/login', (_) => false);
}
