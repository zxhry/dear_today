import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/letter_store.dart';
import '../models/letter.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/buttons.dart';
import '../widgets/postmark.dart';
import '../widgets/stamp.dart';
import '../widgets/stamp_picture.dart';
import '../widgets/step_header.dart';
import 'letter_screen.dart';

/// Step 3: the signature moment. The postmark thunks down, the seal pops in.
class SealedScreen extends StatefulWidget {
  final Letter letter;
  final bool edited; // true when changes to an existing letter were saved
  const SealedScreen({super.key, required this.letter, this.edited = false});

  @override
  State<SealedScreen> createState() => _SealedScreenState();
}

class _SealedScreenState extends State<SealedScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _stamp;
  late final Animation<double> _seal;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _stamp = CurvedAnimation(parent: _c, curve: const Interval(0.1, 0.45, curve: Curves.easeOutBack));
    _seal = CurvedAnimation(parent: _c, curve: const Interval(0.5, 0.85, curve: Curves.elasticOut));
    _c.forward();
    // A little buzz the moment the postmark lands.
    Future.delayed(const Duration(milliseconds: 620), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final number = LetterStore.instance.numberInMonth(letter);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(step: 3, title: widget.edited ? 'Edit letter' : 'Write to today'),
            const Spacer(flex: 2),
            SizedBox(
              width: 300,
              height: 200,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Envelope.
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: AppColors.ink.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 8)),
                          BoxShadow(color: AppColors.ink.withValues(alpha: 0.12), offset: const Offset(0, 3)),
                        ],
                      ),
                      child: CustomPaint(painter: _FlapPainter()),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    bottom: 22,
                    child: Text('To: ${weekdayName(letter.date)}', style: AppText.hand(20)),
                  ),
                  // Wax seal.
                  Positioned(
                    left: 124,
                    top: 92,
                    child: ScaleTransition(
                      scale: _seal,
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                          boxShadow: [
                            BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), spreadRadius: 4),
                            const BoxShadow(color: AppColors.ink, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Text('DT', style: AppText.hand(22, color: AppColors.white)),
                      ),
                    ),
                  ),
                  // Today's stamp in the corner.
                  Positioned(
                    right: 14,
                    top: 14,
                    child: StampFrame(
                      holeRadius: 2.6,
                      tilt: 4,
                      child: SizedBox(
                        width: 48,
                        height: 58,
                        child: StampPicture(photoPath: letter.photoPath, doodle: letter.doodle, iconSize: 24),
                      ),
                    ),
                  ),
                  // Postmark, stamped down from above.
                  Positioned(
                    right: -18,
                    top: -12,
                    child: AnimatedBuilder(
                      animation: _stamp,
                      builder: (context, child) => Opacity(
                        opacity: _stamp.value.clamp(0.0, 1.0),
                        child: Transform.scale(scale: 1.9 - 0.9 * _stamp.value, child: child),
                      ),
                      child: Postmark(date: letter.date, size: 76),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(widget.edited ? 'Resealed!' : 'Sealed & saved!', style: AppText.hand(38)),
                  const SizedBox(height: 8),
                  Text(
                    widget.edited
                        ? 'Your changes to Letter No. $number are saved.'
                        : 'Letter No. $number is tucked into your ${monthName(letter.date)} mailbox.',
                    textAlign: TextAlign.center,
                    style: AppText.body(15, weight: FontWeight.w500, color: const Color(0xFF3A4668)),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SoftButton(
                      label: 'Read it again',
                      icon: Icons.mail_outline,
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => LetterScreen(letter: letter)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ChunkyButton(
                    label: 'Back to my letters',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final faint = Paint()
      ..color = const Color(0xFFDCE3EF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, h), Offset(w * 0.4, h * 0.54), faint);
    canvas.drawLine(Offset(w, h), Offset(w * 0.6, h * 0.54), faint);

    final flap = Path()
      ..moveTo(0, 0)
      ..lineTo(w / 2, h * 0.59)
      ..lineTo(w, 0);
    canvas.drawPath(flap, Paint()..color = const Color(0xFFFBF6F0));
    canvas.drawPath(
      flap,
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
