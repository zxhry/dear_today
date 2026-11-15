import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'vault_image.dart';

/// A postage-stamp frame: paper with little half-circle "bites" along
/// every edge (the perforation), plus a soft shadow.
///
/// Whatever you pass as [child] sits inside the paper border.
class StampFrame extends StatelessWidget {
  final Widget child;
  final double holeRadius; // size of each perforation bite
  final double tilt; // rotation in degrees, for the hand-stuck look

  const StampFrame({super.key, required this.child, this.holeRadius = 3, this.tilt = 0});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return Transform.rotate(
      angle: tilt * math.pi / 180,
      child: CustomPaint(
        painter: _StampPainter(holeRadius: holeRadius, paper: t.stampPaper, shadow: t.shadow),
        child: Padding(
          // Keep the content clear of the perforated edge.
          padding: EdgeInsets.all(holeRadius * 2.2),
          child: child,
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final double holeRadius;
  final Color paper, shadow;
  _StampPainter({required this.holeRadius, required this.paper, required this.shadow});

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = Path()..addRect(Offset.zero & size);
    final holes = Path();
    final gap = holeRadius * 3; // distance between hole centres

    // Top and bottom edges.
    final countX = math.max(1, (size.width / gap).floor());
    final startX = (size.width - (countX - 1) * gap) / 2;
    for (var i = 0; i < countX; i++) {
      final x = startX + i * gap;
      holes.addOval(Rect.fromCircle(center: Offset(x, 0), radius: holeRadius));
      holes.addOval(Rect.fromCircle(center: Offset(x, size.height), radius: holeRadius));
    }

    // Left and right edges.
    final countY = math.max(1, (size.height / gap).floor());
    final startY = (size.height - (countY - 1) * gap) / 2;
    for (var i = 0; i < countY; i++) {
      final y = startY + i * gap;
      holes.addOval(Rect.fromCircle(center: Offset(0, y), radius: holeRadius));
      holes.addOval(Rect.fromCircle(center: Offset(size.width, y), radius: holeRadius));
    }

    // Cut the holes out of the paper.
    final stamp = Path.combine(PathOperation.difference, sheet, holes);
    canvas.drawShadow(stamp, shadow, 3, false);
    canvas.drawPath(stamp, Paint()..color = paper);
  }

  @override
  bool shouldRepaint(_StampPainter old) =>
      old.holeRadius != holeRadius || old.paper != paper || old.shadow != shadow;
}

/// A stamp showing its encrypted photo.
class StampPhoto extends StatelessWidget {
  final Stamp stamp;
  final double holeRadius;
  final double tilt;
  final int? decodeWidth;
  final double? aspect; // defaults to the stamp's own shape

  const StampPhoto({
    super.key,
    required this.stamp,
    this.holeRadius = 3,
    this.tilt = 0,
    this.decodeWidth = 360,
    this.aspect,
  });

  @override
  Widget build(BuildContext context) {
    final tone = DT.tones[stamp.id.hashCode.abs() % DT.tones.length];
    return StampFrame(
      holeRadius: holeRadius,
      tilt: tilt,
      child: AspectRatio(
        aspectRatio: aspect ?? stamp.shape.aspect,
        child: VaultImage(
          path: stamp.photoPath,
          decodeWidth: decodeWidth,
          fallback: Container(color: tone),
        ),
      ),
    );
  }
}

/// An empty stamp-shaped slot (a collection with nothing in it yet).
class EmptyStamp extends StatelessWidget {
  final double holeRadius;
  const EmptyStamp({super.key, this.holeRadius = 2.6});

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    return StampFrame(
      holeRadius: holeRadius,
      child: Container(
        color: t.surf2,
        alignment: Alignment.center,
        child: Icon(Icons.local_post_office_outlined, size: 20, color: t.muted),
      ),
    );
  }
}
