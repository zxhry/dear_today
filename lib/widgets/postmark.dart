import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/dates.dart';

/// The round "SEALED · 20 OCT · 2026" postmark with wavy cancellation lines.
class Postmark extends StatelessWidget {
  final DateTime date;
  final String label;
  final double size;

  const Postmark({super.key, required this.date, this.label = 'SEALED', this.size = 86});

  @override
  Widget build(BuildContext context) {
    final small = AppText.body(size * 0.105, weight: FontWeight.w800).copyWith(letterSpacing: 1.4);
    return ExcludeSemantics(
      child: Opacity(
        opacity: 0.85,
        child: Transform.rotate(
          angle: 14 * math.pi / 180,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(size: Size(size * 0.5, size * 0.38), painter: _WavesPainter()),
              const SizedBox(width: 2),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.35),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: small),
                    const SizedBox(height: 2),
                    Text('${date.day} ${shortMonth(date).toUpperCase()}', style: AppText.hand(size * 0.23)),
                    const SizedBox(height: 2),
                    Text('${date.year}', style: small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 56, size.height / 40);
    final paint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 3; row++) {
      final path = Path()..moveTo(2, 8.0 + row * 12);
      for (var i = 0; i < 4; i++) {
        path.relativeQuadraticBezierTo(6.5, i.isEven ? -6 : 6, 13, 0);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
