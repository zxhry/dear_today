import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// A postage-stamp frame: white paper with little half-circle "bites"
/// along every edge (the perforation), plus a soft shadow.
///
/// Whatever you pass as [child] sits inside the white border.
class StampFrame extends StatelessWidget {
  final Widget child;
  final double holeRadius; // size of each perforation bite
  final double tilt; // rotation in degrees, for the hand-stuck look

  const StampFrame({
    super.key,
    required this.child,
    this.holeRadius = 3.5,
    this.tilt = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt * math.pi / 180,
      child: CustomPaint(
        painter: _StampPainter(holeRadius: holeRadius),
        child: Padding(
          // Keep the content clear of the perforated edge.
          padding: EdgeInsets.all(holeRadius * 2.4),
          child: child,
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final double holeRadius;
  _StampPainter({required this.holeRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paper = Path()..addRect(Offset.zero & size);
    final holes = Path();
    final gap = holeRadius * 2.8; // distance between hole centres

    // Top and bottom edges.
    final countX = (size.width / gap).floor();
    final startX = (size.width - (countX - 1) * gap) / 2;
    for (var i = 0; i < countX; i++) {
      final x = startX + i * gap;
      holes.addOval(Rect.fromCircle(center: Offset(x, 0), radius: holeRadius));
      holes.addOval(Rect.fromCircle(center: Offset(x, size.height), radius: holeRadius));
    }

    // Left and right edges.
    final countY = (size.height / gap).floor();
    final startY = (size.height - (countY - 1) * gap) / 2;
    for (var i = 0; i < countY; i++) {
      final y = startY + i * gap;
      holes.addOval(Rect.fromCircle(center: Offset(0, y), radius: holeRadius));
      holes.addOval(Rect.fromCircle(center: Offset(size.width, y), radius: holeRadius));
    }

    // Cut the holes out of the paper.
    final stamp = Path.combine(PathOperation.difference, paper, holes);

    canvas.drawShadow(stamp, AppColors.ink.withValues(alpha: 0.5), 3, false);
    canvas.drawPath(stamp, Paint()..color = AppColors.white);
  }

  @override
  bool shouldRepaint(_StampPainter old) => old.holeRadius != holeRadius;
}
