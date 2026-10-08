import 'package:flutter/material.dart';

/// Palette officielle eDoctor Pharmacie — conforme à EDOCTOR_MAQUETTE_INTERFACE/e_doctor_pharmacy/DESIGN.md
/// Base : Coral Orange (#F97316) + Slate Blue (#0F172A) + Fond clinique (#F8F9FF)
class AppColors {
  AppColors._();

  // Marque principale : Vert eDoctor officiel (issu du logo)
  static const Color primary = Color(0xFF529927);
  static const Color primaryHover = Color(0xFF427A1F);
  static const Color primaryLight = Color(0xFF7ABF45);
  static const Color primaryContainer = Color(0xFFEAF5DF);
  static const Color onPrimary = Colors.white;

  // Secondaire : Bleu Nuit Profond (issu du logo "DOCTOR by EWARE Group")
  static const Color secondary = Color(0xFF132A45);
  static const Color secondaryLight = Color(0xFF1D3B60);
  static const Color secondaryContainer = Color(0xFFE6EEF8);

  // Surfaces & Arrière-plans (Clean Clinical & Frais)
  static const Color background = Color(0xFFF7FAF6);
  static const Color surface = Colors.white;
  static const Color surfaceDim = Color(0xFFF1F5F0);

  // Textes & Typographie
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Bordures architecturales fines (1px Low-Contrast Outline)
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderHover = Color(0xFFCBD5E1);

  // Statuts Métier Pharmacie (Stocks & Ordonnances)
  static const Color inStock = Color(0xFF16A34A);         // En stock
  static const Color inStockLight = Color(0xFFDCFCE7);
  static const Color lowStock = Color(0xFFF97316);        // Stock faible
  static const Color lowStockLight = Color(0xFFFFEDD5);
  static const Color outOfStock = Color(0xFFDC2626);      // Rupture de stock
  static const Color outOfStockLight = Color(0xFFFEE2E2);

  // Statuts Commandes
  static const Color orderPending = Color(0xFFD97706);
  static const Color orderPendingLight = Color(0xFFFEF3C7);
  static const Color orderReady = Color(0xFF2563EB);
  static const Color orderReadyLight = Color(0xFFDBEAFE);
  static const Color orderCompleted = Color(0xFF16A34A);
  static const Color orderCompletedLight = Color(0xFFDCFCE7);
  static const Color orderCancelled = Color(0xFFDC2626);
  static const Color orderCancelledLight = Color(0xFFFEE2E2);
}
