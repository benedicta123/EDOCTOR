import 'package:flutter/material.dart';

/// Palette officielle conforme à l'identité visuelle eDoctor (Logo & Charte graphique)
/// Vert officiel : #529927 | Bleu Nuit Profond : #132A45 | Fond clinique : #F7FAF6
class AppColors {
  AppColors._();

  // Marque principale : Vert eDoctor officiel (issu du logo eDoctor)
  static const Color primary = Color(0xFF529927);
  static const Color primaryHover = Color(0xFF427A1F);
  static const Color primaryLight = Color(0xFF7ABF45);
  static const Color primaryContainer = Color(0xFFEAF5DF);
  static const Color onPrimary = Colors.white;

  // Secondaire & Navigation : Bleu Nuit Profond (issu du logo eDoctor "DOCTOR by EWARE Group")
  static const Color secondary = Color(0xFF132A45);
  static const Color secondaryLight = Color(0xFF1D3B60);
  static const Color secondaryContainer = Color(0xFFE6EEF8);

  // Barre latérale (Sidebar) - Identité régalienne eDoctor
  static const Color sidebarBg = Color(0xFF132A45);
  static const Color sidebarSurface = Color(0xFF1D3B60);
  static const Color sidebarBorder = Color(0xFF24446A);
  static const Color sidebarActive = Color(0xFF529927); // Vert eDoctor pour l'élément actif

  // Statuts de Conformité & Régulation
  static const Color verified = Color(0xFF529927); // Vert eDoctor / Homologué
  static const Color verifiedBg = Color(0xFFEAF5DF);
  static const Color verifiedBorder = Color(0xFFBCE39A);

  static const Color pending = Color(0xFFD97706); // Ambre / En attente d'audit
  static const Color pendingBg = Color(0xFFFFFBEB);
  static const Color pendingBorder = Color(0xFFFDE68A);

  static const Color rejected = Color(0xFFDC2626); // Rouge vif / Rejeté
  static const Color rejectedBg = Color(0xFFFEF2F2);
  static const Color rejectedBorder = Color(0xFFFECACA);

  static const Color suspended = Color(0xFF7C3AED); // Pourpre / Suspendu
  static const Color suspendedBg = Color(0xFFF5F3FF);
  static const Color suspendedBorder = Color(0xFFDDD6FE);

  // Surfaces & Fonds (Clean Clinical & Frais)
  static const Color background = Color(0xFFF7FAF6);
  static const Color surface = Colors.white;
  static const Color surfaceDim = Color(0xFFF1F5F0);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFCBD5E1);

  // Typographie & Contrastes
  static const Color textPrimary = Color(0xFF132A45); // Bleu Nuit
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = Colors.white;

  // Priorités Réclamations
  static const Color priorityUrgent = Color(0xFFBE123C); // Rose 700
  static const Color priorityHigh = Color(0xFFEA580C); // Orange 600
  static const Color priorityNormal = Color(0xFF2563EB); // Bleu 600
  static const Color priorityLow = Color(0xFF64748B); // Slate 500
}
