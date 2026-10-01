import 'package:flutter/material.dart';

/// Clé de navigation globale — permet à ApiService de rediriger vers
/// la connexion depuis n'importe où, sans BuildContext.
///
/// Usage dans MaterialApp :
///   navigatorKey: AppRouter.navigatorKey,
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'edoctor_mobile_root');

/// Redirige vers l'écran d'inscription/connexion et efface tout l'historique.
/// Appelé automatiquement par ApiService dès qu'un 401 est reçu en session.
void redirectToLogin() {
  final ctx = appNavigatorKey.currentContext;
  if (ctx == null) return;
  Navigator.of(ctx).pushNamedAndRemoveUntil('/register', (_) => false);
}
