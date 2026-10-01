import 'package:flutter/material.dart';

/// Clé de navigation globale pour l'espace Praticien — permet à ApiService
/// de rediriger vers l'écran de connexion lorsque le token expire (401),
/// sans nécessiter de BuildContext local.
final GlobalKey<NavigatorState> praticienNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'edoctor_praticien_root');

/// Redirige vers /login et vide la pile de navigation.
void redirectToLogin() {
  final ctx = praticienNavigatorKey.currentContext;
  if (ctx == null) return;
  Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (_) => false);
}
