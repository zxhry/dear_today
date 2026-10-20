import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// A coral wax seal with a wavy, melted edge and letters pressed into it.
class WaxSeal extends StatelessWidget {
  final double size;
  final String text;
  const WaxSeal({super.key, this.size = 58, this.text = 'DT'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WaxPainter(),
        child: Center(
          child: Text(
            text,
            style: AppText.hand(size * 0.36, color: AppColors.white).copyWith(
              // A soft shadow makes the letters look pressed into the wax.
              shadows: const [Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 1)],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 * 0.9;

    // Wobbly outer edge, like melted wax.
    final blob = Path();
    const steps = 72;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * math.pi;
      final rr = r * (1 + 0.055 * math.sin(a * 9) + 0.03 * math.sin(a * 4 + 1.3));
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? blob.moveTo(p.dx, p.dy) : blob.lineTo(p.dx, p.dy);
    }
    blob.close();

    canvas.drawShadow(blob, AppColors.ink, 2.5, false);
    canvas.drawPath(blob, Paint()..color = AppColors.accent);

    // Pressed inner ring.
    canvas.drawCircle(
      c,
      r * 0.68,
      Paint()
        ..color = const Color(0xFF9E3A2B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.045,
    );
    // A little shine on the top-left.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.84),
      math.pi * 1.1,
      math.pi * 0.45,
      false,
      Paint()
        ..color = AppColors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.04
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
