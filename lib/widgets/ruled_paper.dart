import 'package:flutter/material.dart';
import '../theme.dart';

/// A sheet of lined writing paper. Grows with the letter, but never shorter
/// than [minHeight].
class RuledPaper extends StatelessWidget {
  final Widget child;
  final double lineHeight;
  final double firstLine; // how far down the first ruled line starts
  final double minHeight; // short letters still look like a full sheet

  const RuledPaper({
    super.key,
    required this.child,
    this.lineHeight = 30,
    this.firstLine = 0,
    this.minHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.12), offset: const Offset(0, 3))],
      ),
      child: CustomPaint(
        painter: _LinesPainter(lineHeight, firstLine),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 16), child: child),
        ),
      ),
    );
  }
}

class _LinesPainter extends CustomPainter {
  final double lineHeight;
  final double firstLine;
  _LinesPainter(this.lineHeight, this.firstLine);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCE3EF)
      ..strokeWidth = 1;
    for (var y = firstLine + lineHeight; y < size.height - 8; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) => old.lineHeight != lineHeight || old.firstLine != firstLine;
}
