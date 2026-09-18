import 'package:flutter/material.dart';

/// Palette de couleurs fidèle au Design System eDoctor / Togo Health Direct
class AppColors {
  AppColors._();

  // Teintes Principales (Vert officiel du logo eDoctor — échantillonné #529927)
  static const Color primary = Color(0xFF529927);
  static const Color primaryHover = Color(0xFF427A1F);
  static const Color primaryLight = Color(0xFF7ABF45);
  static const Color primaryContainer = Color(0xFFEAF5DF);
  static const Color onPrimary = Colors.white;

  // Teintes Secondaires (Bleu nuit du logo — échantillonné #132A45)
  static const Color secondary = Color(0xFF132A45);
  static const Color secondaryContainer = Color(0xFFDCE6F2);
  static const Color onSecondaryContainer = Color(0xFF132A45);

  // Surfaces & Arrière-plans
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color surfaceDim = Color(0xFFE2E8F0);
  static const Color surfaceContainer = Color(0xFFEFF6E8);
  static const Color surfaceContainerHigh = Color(0xFFD9EAC8);

  // Textes & Typographie
  static const Color textPrimary = Color(0xFF132A45);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnDark = Colors.white;

  // Bordures & Décorations
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderFocus = Color(0xFF529927);

  // États sémantiques (Santé)
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFFA7F3D0);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color warningContainer = Color(0xFFF38764);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorLight = Color(0xFFFFDAD6);

  // Drapeau Togo (pour indicatif téléphonique +228)
  static const Color togoGreen = Color(0xFF006A4E);
  static const Color togoYellow = Color(0xFFFFCE00);
  static const Color togoRed = Color(0xFFD21034);
}
