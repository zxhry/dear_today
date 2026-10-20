import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/letter_store.dart';
import '../data/tomorrow_store.dart';
import '../models/future_letter.dart';
import '../models/letter.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/buttons.dart';
import '../widgets/stamp.dart';
import '../widgets/stamp_picture.dart';
import 'month_letters_screen.dart';
import 'tomorrow_letter_screen.dart';
import 'write_tomorrow_screen.dart';

/// The Mailbox tab: letters to tomorrow, and each month tied into a bundle.
class MailboxScreen extends StatelessWidget {
  const MailboxScreen({super.key});

  void _open(BuildContext context, FutureLetter f) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TomorrowLetterScreen(letter: f)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([TomorrowStore.instance, LetterStore.instance]),
      builder: (context, _) {
        final tomorrow = TomorrowStore.instance;
        final arrived = tomorrow.arrived;
        final waiting = tomorrow.waiting;
        final read = tomorrow.read;
        final bundles = _bundles(LetterStore.instance.all);
        final total = LetterStore.instance.all.length;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Text('My mailbox', style: AppText.hand(40)),
              const SizedBox(height: 16),
              _MailboxCard(
                arrived: arrived,
                waiting: waiting,
                onOpen: arrived.isEmpty ? null : () => _open(context, arrived.first),
              ),
              const SizedBox(height: 14),
              ChunkyButton(
                label: 'Write to tomorrow',
                icon: Icons.forward_to_inbox_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WriteTomorrowScreen()),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text('Monthly bundles', style: AppText.hand(28))),
                  Text('$total ${total == 1 ? 'letter' : 'letters'} in all',
                      style: AppText.body(12, color: AppColors.inkSoft)),
                ],
              ),
              const SizedBox(height: 10),
              if (bundles.isEmpty)
                Text('Your first bundle appears after your first letter.',
                    style: AppText.body(14, color: AppColors.inkSoft))
              else
                for (final b in bundles) ...[
                  _BundleCard(bundle: b),
                  const SizedBox(height: 12),
                ],
              if (read.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('From yesterday\'s you', style: AppText.hand(28)),
                const SizedBox(height: 8),
                for (final f in read) _ReadRow(letter: f, onTap: () => _open(context, f)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Groups letters by month, newest month first.
  static List<_Bundle> _bundles(List<Letter> letters) {
    final out = <_Bundle>[];
    for (final l in letters) {
      if (out.isEmpty || out.last.month.year != l.date.year || out.last.month.month != l.date.month) {
        out.add(_Bundle(DateTime(l.date.year, l.date.month), []));
      }
      out.last.letters.add(l);
    }
    return out;
  }
}

class _Bundle {
  final DateTime month;
  final List<Letter> letters;
  _Bundle(this.month, this.letters);
}

class _MailboxCard extends StatelessWidget {
  final List<FutureLetter> arrived;
  final List<FutureLetter> waiting;
  final VoidCallback? onOpen;
  const _MailboxCard({required this.arrived, required this.waiting, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final hasMail = arrived.isNotEmpty;
    final String label, headline;
    final Widget detail;

    if (hasMail) {
      label = 'FLAG IS UP';
      headline = arrived.length == 1 ? 'A letter from yesterday\'s you!' : '${arrived.length} letters have arrived!';
      detail = Text('Tap to open', style: AppText.body(13, weight: FontWeight.w800, color: AppColors.accent));
    } else if (waiting.isNotEmpty) {
      final next = waiting.first;
      label = 'SEALED';
      headline = waiting.length == 1 ? 'A letter to tomorrow is waiting' : '${waiting.length} letters are waiting';
      detail = Row(
        children: [
          const Icon(Icons.lock_outline, size: 14, color: AppColors.inkSoft),
          const SizedBox(width: 4),
          Text('Opens ${shortWeekday(next.openOn)}, ${next.openOn.day} ${shortMonth(next.openOn)}',
              style: AppText.body(13, weight: FontWeight.w700, color: AppColors.inkSoft)),
        ],
      );
    } else {
      label = 'EMPTY MAILBOX';
      headline = 'Nothing waiting yet';
      detail = Text('Write a note for tomorrow-you to find.', style: AppText.body(13, color: AppColors.inkSoft));
    }

    return Semantics(
      button: hasMail,
      label: '$headline. ${hasMail ? 'Tap to open.' : ''}',
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hasMail ? AppColors.accent : AppColors.ink.withValues(alpha: 0.12), width: hasMail ? 2 : 1),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  _MailboxDrawing(flagUp: hasMail, sleepy: waiting.isNotEmpty),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: AppText.body(11, weight: FontWeight.w800, color: AppColors.accent)
                                .copyWith(letterSpacing: 1.4)),
                        const SizedBox(height: 4),
                        Text(headline, style: AppText.hand(24)),
                        const SizedBox(height: 6),
                        detail,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A cute little mailbox with a face.
/// - Mail arrived: happy eyes, an envelope peeking out, flag up.
/// - Letter waiting: sleepy, dreaming of tomorrow ("z z").
/// - Empty: just smiling.
class _MailboxDrawing extends StatelessWidget {
  final bool flagUp;
  final bool sleepy;
  const _MailboxDrawing({required this.flagUp, this.sleepy = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Flag angle: 0 = straight up (mail!), otherwise tilted down.
      tween: Tween(end: flagUp ? 0 : 0.62 * math.pi),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, angle, _) => CustomPaint(
        size: const Size(92, 94),
        painter: _MailboxPainter(flagAngle: angle, hasMail: flagUp, sleepy: sleepy && !flagUp),
      ),
    );
  }
}

class _MailboxPainter extends CustomPainter {
  final double flagAngle;
  final bool hasMail;
  final bool sleepy;
  _MailboxPainter({required this.flagAngle, required this.hasMail, required this.sleepy});

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..style = PaintingStyle.fill;

    // Ground and post.
    canvas.drawLine(const Offset(16, 91), const Offset(70, 91), ink);
    final post = RRect.fromLTRBR(37, 60, 47, 91, const Radius.circular(2));
    canvas.drawRRect(post, fill..color = AppColors.ink);

    // Body: a box with a rounded, bread-loaf top.
    final body = Path()
      ..moveTo(12, 62)
      ..lineTo(12, 32)
      ..arcToPoint(const Offset(72, 32), radius: const Radius.circular(30))
      ..lineTo(72, 62)
      ..close();
    canvas.drawPath(body, fill..color = AppColors.sky);
    canvas.drawPath(body, ink);

    // Mail slot, with an envelope peeking out when mail has arrived.
    if (hasMail) {
      final env = RRect.fromLTRBR(31, 40, 53, 54, const Radius.circular(1.5));
      canvas.drawRRect(env, fill..color = AppColors.white);
      canvas.drawRRect(env, ink..strokeWidth = 2);
      canvas.drawPath(
        Path()
          ..moveTo(31.5, 41)
          ..lineTo(42, 48)
          ..lineTo(52.5, 41),
        ink,
      );
      canvas.drawCircle(const Offset(42, 48), 2.6, fill..color = AppColors.accent); // tiny wax seal
    }
    final slot = RRect.fromLTRBR(26, 52, 58, 57, const Radius.circular(2.5));
    canvas.drawRRect(slot, fill..color = AppColors.white);
    canvas.drawRRect(slot, ink..strokeWidth = 2.2);
    ink.strokeWidth = 2.5;

    // Blush.
    fill.color = const Color(0xFFF6B7A8);
    canvas.drawOval(Rect.fromCenter(center: const Offset(23, 33), width: 7, height: 4.5), fill);
    canvas.drawOval(Rect.fromCenter(center: const Offset(61, 33), width: 7, height: 4.5), fill);

    // Eyes.
    if (sleepy) {
      // Closed, curved-down eyes.
      for (final x in [31.0, 53.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 3.5, 27)
            ..quadraticBezierTo(x, 30.5, x + 3.5, 27),
          ink..strokeWidth = 2,
        );
      }
    } else {
      for (final x in [31.0, 53.0]) {
        final r = hasMail ? 3.3 : 2.6; // bigger, sparkly eyes when mail has come
        canvas.drawCircle(Offset(x, 28), r, fill..color = AppColors.ink);
        canvas.drawCircle(Offset(x + 1, 27), r * 0.35, fill..color = AppColors.white);
      }
    }

    // Mouth: a big open smile with mail, a small one otherwise.
    ink.strokeWidth = 2;
    if (hasMail) {
      final mouth = Path()
        ..moveTo(37, 33)
        ..quadraticBezierTo(42, 40, 47, 33)
        ..close();
      canvas.drawPath(mouth, fill..color = AppColors.ink);
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(38.5, 34)
          ..quadraticBezierTo(42, 37, 45.5, 34),
        ink,
      );
    }

    // "z z" while it sleeps.
    if (sleepy) {
      void z(double x, double y, double s) {
        canvas.drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(x + s, y)
            ..lineTo(x, y + s)
            ..lineTo(x + s, y + s),
          Paint()
            ..color = AppColors.inkSoft
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
      z(4, 10, 6);
      z(-2, 0, 4.5);
    }

    // Flag on a little pivot at the right side.
    canvas.save();
    canvas.translate(72, 46);
    canvas.rotate(flagAngle);
    canvas.drawLine(Offset.zero, const Offset(0, -20), ink..strokeWidth = 2.5);
    final flag = RRect.fromLTRBR(0, -21, 13, -12, const Radius.circular(2));
    canvas.drawRRect(flag, fill..color = AppColors.accent);
    canvas.drawRRect(flag, ink..strokeWidth = 2);
    canvas.restore();
    canvas.drawCircle(const Offset(72, 46), 2.6, fill..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_MailboxPainter old) =>
      old.flagAngle != flagAngle || old.hasMail != hasMail || old.sleepy != sleepy;
}

class _BundleCard extends StatelessWidget {
  final _Bundle bundle;
  const _BundleCard({required this.bundle});

  static const _fan = [(-10.0, 0.0, 6.0), (3.0, 22.0, 2.0), (12.0, 44.0, 8.0)]; // (tilt, left, top)

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = bundle.month.year == now.year && bundle.month.month == now.month;
    final n = bundle.letters.length;
    final shown = bundle.letters.take(3).toList();

    return Semantics(
      button: true,
      label: '${monthYear(bundle.month)}, $n ${n == 1 ? 'letter' : 'letters'}',
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MonthLettersScreen(month: bundle.month)),
          ),
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isCurrent ? AppColors.accent : AppColors.ink, width: isCurrent ? 2 : 1.5),
            ),
            child: ExcludeSemantics(
              child: Stack(
                children: [
                  // The string tying the bundle.
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 41,
                    child: ColoredBox(color: Color(0xFFE3C9A8), child: SizedBox(height: 2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          height: 70,
                          child: Stack(
                            children: [
                              for (var i = 0; i < shown.length; i++)
                                Positioned(
                                  left: _fan[i].$2,
                                  top: _fan[i].$3,
                                  child: StampFrame(
                                    holeRadius: 1.9,
                                    tilt: _fan[i].$1,
                                    child: SizedBox(
                                      width: 32,
                                      height: 40,
                                      child: StampPicture(
                                        photoPath: shown[i].photoPath,
                                        doodle: shown[i].doodle,
                                        iconSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            color: AppColors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bundle.month.year == now.year ? monthName(bundle.month) : monthYear(bundle.month),
                                  style: AppText.hand(24),
                                ),
                                const SizedBox(height: 2),
                                Text('$n ${n == 1 ? 'letter' : 'letters'}, tied with string',
                                    style: AppText.body(12, color: AppColors.inkSoft)),
                              ],
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                            child: Text('This month',
                                style: AppText.body(11, weight: FontWeight.w800, color: AppColors.white)),
                          ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: AppColors.ink),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  final FutureLetter letter;
  final VoidCallback onTap;
  const _ReadRow({required this.letter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.drafts_outlined, color: AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Written ${longDate(letter.writtenAt)}',
                      style: AppText.body(12, weight: FontWeight.w800, color: AppColors.inkSoft)),
                  Text(letter.body, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppText.body(14, weight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}
