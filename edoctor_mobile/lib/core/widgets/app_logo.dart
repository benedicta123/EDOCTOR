import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Widget réutilisable pour afficher le logo officiel d'eDoctor
/// Si le fichier 'assets/images/logo.png' n'est pas encore présent,
/// un fallback élégant avec l'icône médicale s'affiche automatiquement.
class AppLogo extends StatelessWidget {
  /// Hauteur de référence. Conservé pour compatibilité ascendante :
  /// si [width] / [height] ne sont pas fournis, le logo est carré size x size.
  /// Pour le logo eDoctor (bannière horizontale large), préférez
  /// `AppLogo(width: 160, height: 64)` plutôt que d'augmenter `size`,
  /// sinon l'image reste contrainte dans un carré et paraît petite.
  final double size;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.size = 120,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final radius =
        borderRadius ?? BorderRadius.circular(effectiveHeight * 0.28);

    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        'assets/images/logo.png',
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // Fallback gracieux si l'image physique n'a pas encore été déposée
          return Container(
            width: effectiveWidth,
            height: effectiveHeight,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: radius,
            ),
            child: Center(
              child: Icon(
                Icons.medical_services_rounded,
                color: Colors.white,
                size: effectiveHeight * 0.55,
              ),
            ),
          );
        },
      ),
    );
  }
}
