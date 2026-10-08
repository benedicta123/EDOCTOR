import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Drapeau officiel de la République Togolaise
/// 5 bandes horizontales alternées (3 vertes, 2 jaunes),
/// canton rouge carré de 3 bandes avec une étoile blanche à 5 branches au centre.
class TogoFlagWidget extends StatelessWidget {
  final double width;
  final double height;

  const TogoFlagWidget({
    super.key,
    this.width = 24,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2.5),
        border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        size: Size(width, height),
        painter: _TogoFlagPainter(),
      ),
    );
  }
}

class _TogoFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stripeHeight = size.height / 5.0;
    // Couleurs officielles du drapeau togolais
    final greenPaint = Paint()..color = const Color(0xFF006A4E);
    final yellowPaint = Paint()..color = const Color(0xFFFFCE00);
    final redPaint = Paint()..color = const Color(0xFFD21034);
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // 1. Les 5 bandes alternées vertes et jaunes
    for (int i = 0; i < 5; i++) {
      final paint = (i % 2 == 0) ? greenPaint : yellowPaint;
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight),
        paint,
      );
    }

    // 2. Le canton rouge carré occupant la hauteur des 3 premières bandes
    final cantonSide = stripeHeight * 3.0;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cantonSide, cantonSide),
      redPaint,
    );

    // 3. L'étoile blanche à 5 branches parfaitement centrée dans le carré rouge
    final cx = cantonSide / 2.0;
    final cy = cantonSide / 2.0;
    final rOuter = cantonSide * 0.36;
    final rInner = rOuter * 0.382;

    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (i * 36 - 90) * (math.pi / 180.0);
      final r = (i % 2 == 0) ? rOuter : rInner;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
