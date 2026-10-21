import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'buttons.dart';

/// Things the tour points at. Screens attach these keys to their widgets.
class TourTargets {
  static final write = GlobalKey(debugLabel: 'tour-write');
  static final days = GlobalKey(debugLabel: 'tour-days');
  static final nav = GlobalKey(debugLabel: 'tour-nav');
}

class _Step {
  final Color color;
  final String title;
  final String desc;
  final String? kicker; // null = a centred welcome / finish card
  final GlobalKey? target;
  final int navSlot; // which bottom tab (0-3), when target is the nav bar
  const _Step(this.color, this.title, this.desc,
      {this.kicker, this.target, this.navSlot = -1});
}

const _coral = Color(0xFFE07A5F);
const _sky = Color(0xFF5B9BD5);
const _butter = Color(0xFFE9B949);
const _mint = Color(0xFF5DAE7E);
const _lilac = Color(0xFF9C7FD6);

/// A first-time tour: dims the app, spotlights one feature at a time, and
/// points at it with a colourful hand-drawn arrow and a stamp-edged note.
class TourOverlay extends StatefulWidget {
  final VoidCallback onFinish;
  const TourOverlay({super.key, required this.onFinish});

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> with SingleTickerProviderStateMixin {
  final _steps = <_Step>[
    const _Step(_coral, 'Welcome to Dear Today!', 'A little letter to each day. Let’s take a quick look around.'),
    _Step(_coral, 'Write to today', 'Pick a photo, write a few lines, and seal it with a stamp.',
        kicker: 'WRITE', target: TourTargets.write),
    _Step(_sky, 'Flip through your days', 'Tap the arrows or swipe left and right to visit past days.',
        kicker: 'YOUR DAYS', target: TourTargets.days),
    _Step(_butter, 'Your month at a glance', 'Every day you wrote shows up as a tiny stamp.',
        kicker: 'CALENDAR', target: TourTargets.nav, navSlot: 1),
    _Step(_mint, 'Letters to tomorrow', 'Write a note to future you. It arrives the next morning at 7:00 am.',
        kicker: 'MAILBOX', target: TourTargets.nav, navSlot: 2),
    _Step(_lilac, 'Keep it yours', 'Lock the app, see your moods, set a daily reminder and back up your letters.',
        kicker: 'ME', target: TourTargets.nav, navSlot: 3),
    const _Step(_mint, "You're all set!", 'Your first stamp is waiting. Dear Today is ready when you are.'),
  ];

  int _i = 0;
  Rect? _hole; // the spotlighted area, in this overlay's coordinates
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  _Step get _step => _steps[_i];
  int get _calloutCount => _steps.where((s) => s.kicker != null).length;
  int get _calloutIndex => _steps.take(_i + 1).where((s) => s.kicker != null).length;

  @override
  void initState() {
    super.initState();
    _measureSoon();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _measureSoon() => WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

  /// Finds where the current target sits on screen.
  void _measure() {
    if (!mounted) return;
    final target = _step.target;
    final me = context.findRenderObject() as RenderBox?;
    final box = target?.currentContext?.findRenderObject() as RenderBox?;
    Rect? hole;
    if (me != null && box != null && box.hasSize) {
      final topLeft = me.globalToLocal(box.localToGlobal(Offset.zero));
      var r = topLeft & box.size;
      if (_step.navSlot >= 0) {
        final w = r.width / 4;
        r = Rect.fromLTWH(r.left + w * _step.navSlot, r.top, w, math.min(r.height, 72));
      }
      hole = r.inflate(6);
    }
    setState(() => _hole = hole);
  }

  void _next() {
    if (_i >= _steps.length - 1) {
      widget.onFinish();
      return;
    }
    setState(() {
      _i++;
      _hole = null;
    });
    _measureSoon();
  }

  void _skip() => setState(() {
        _i = _steps.length - 1;
        _hole = null;
      });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final centred = _step.kicker == null;
    final hole = _hole;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dim everything (with a hole for the spotlight) and block taps.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _SpotlightPainter(
                    hole: centred ? null : hole,
                    color: _step.color,
                    pulse: _pulse.value,
                  ),
                ),
              ),
            ),
          ),
          if (centred)
            Center(child: _centreCard(size))
          else if (hole != null)
            ..._callout(size, hole),
        ],
      ),
    );
  }

  /// The note + arrow for a spotlighted feature.
  List<Widget> _callout(Size size, Rect hole) {
    const gap = 70.0; // room for the arrow between note and target
    final cardW = math.min(310.0, size.width - 64);
    final left = (size.width - cardW) / 2;
    final below = hole.center.dy < size.height / 2; // target near top -> note below it
    final arrowStart = below
        ? Offset(size.width / 2 - 14, hole.bottom + gap - 6)
        : Offset(size.width / 2 - 14, hole.top - gap + 6);
    final arrowEnd = below ? Offset(hole.center.dx, hole.bottom + 6) : Offset(hole.center.dx, hole.top - 6);

    final card = SizedBox(width: cardW, child: _noteCard());
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _ArrowPainter(arrowStart, arrowEnd, _step.color, curlRight: _i.isEven)),
        ),
      ),
      if (below)
        Positioned(left: left, top: hole.bottom + gap, child: card)
      else
        Positioned(left: left, bottom: size.height - hole.top + gap, child: card),
    ];
  }

  Widget _noteCard() {
    final s = _step;
    return Semantics(
      container: true,
      label: '${s.title}. ${s.desc}',
      child: _CleanCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.title, style: AppText.hand(24)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(s.desc,
                    style: AppText.body(14, weight: FontWeight.w500, color: AppColors.inkSoft).copyWith(height: 1.45)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton(
                    onPressed: _skip,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 40)),
                    child: Text('Skip', style: AppText.body(13, weight: FontWeight.w700, color: AppColors.inkSoft)),
                  ),
                  const Spacer(),
                  for (var k = 1; k <= _calloutCount; k++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: k == _calloutIndex ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: k == _calloutIndex ? s.color : const Color(0xFFCBD2E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: AppColors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: Text('Next', style: AppText.body(14, weight: FontWeight.w700, color: AppColors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Welcome / finish card with the little envelope friend.
  Widget _centreCard(Size size) {
    final s = _step;
    final first = _i == 0;
    return SizedBox(
      width: math.min(330.0, size.width - 56),
      child: Semantics(
        container: true,
        label: '${s.title}. ${s.desc}',
        child: _CleanCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Bobbing(child: CustomPaint(size: const Size(84, 67), painter: _EnvelopeFriendPainter(s.color))),
                const SizedBox(height: 14),
                Text(s.title, textAlign: TextAlign.center, style: AppText.hand(30)),
                const SizedBox(height: 8),
                Text(s.desc,
                    textAlign: TextAlign.center,
                    style: AppText.body(14, weight: FontWeight.w500, color: AppColors.inkSoft).copyWith(height: 1.5)),
                const SizedBox(height: 16),
                ChunkyButton(label: first ? 'Show me' : 'Start writing', onTap: _next),
                if (first)
                  TextButton(
                    onPressed: widget.onFinish,
                    child: Text('I’ll explore myself',
                        style: AppText.body(13, weight: FontWeight.w800, color: AppColors.inkSoft)),
                  )
                else
                  const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain rounded white card with a soft shadow.
class _CleanCard extends StatelessWidget {
  final Widget child;
  const _CleanCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

/// Gently bobs its child up and down.
class _Bobbing extends StatefulWidget {
  final Widget child;
  const _Bobbing({required this.child});

  @override
  State<_Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<_Bobbing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, -4 * Curves.easeInOut.transform(_c.value)), child: child),
        child: widget.child,
      );
}

/// Dims the screen except a rounded hole, and draws a pulsing dashed ring.
class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  final Color color;
  final double pulse;
  _SpotlightPainter({required this.hole, required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = const Color(0x9922305A);
    final h = hole;
    if (h == null) {
      canvas.drawRect(Offset.zero & size, dim);
      return;
    }
    final r = RRect.fromRectAndRadius(h, Radius.circular(math.min(h.height / 2, 24)));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(r);
    canvas.drawPath(path, dim);

    // A thin outline that softly breathes.
    canvas.drawRRect(
      r.inflate(3 + 2 * pulse),
      Paint()
        ..color = color.withValues(alpha: 0.5 + 0.5 * (1 - pulse))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole || old.color != color || old.pulse != pulse;
}

/// A thick, curvy, hand-drawn arrow with a white outline.
class _ArrowPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;
  final bool curlRight;
  _ArrowPainter(this.from, this.to, this.color, {required this.curlRight});

  @override
  void paint(Canvas canvas, Size size) {
    final dy = to.dy - from.dy;
    final side = curlRight ? 1.0 : -1.0;
    final c1 = Offset(from.dx + 34 * side, from.dy + dy * 0.4);
    final c2 = Offset(to.dx - 26 * side, to.dy - dy * 0.45);
    final line = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, to.dx, to.dy);

    // Arrowhead along the curve's final direction.
    final dir = (to - c2);
    final angle = math.atan2(dir.dy, dir.dx);
    const len = 9.0, spread = 0.55;
    Offset wing(double a) => to - Offset(math.cos(a), math.sin(a)) * len;
    final head = Path()
      ..moveTo(wing(angle - spread).dx, wing(angle - spread).dy)
      ..lineTo(to.dx, to.dy)
      ..lineTo(wing(angle + spread).dx, wing(angle + spread).dy);

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(line, stroke(color, 2.2))
      ..drawPath(head, stroke(color, 2.2));
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.from != from || old.to != to || old.color != color;
}

/// The smiling envelope with blushing cheeks and little sparkles.
class _EnvelopeFriendPainter extends CustomPainter {
  final Color stamp;
  _EnvelopeFriendPainter(this.stamp);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 96);
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = RRect.fromLTRBR(10, 18, 110, 88, const Radius.circular(8));
    canvas.drawRRect(body, Paint()..color = AppColors.butter);
    canvas.drawRRect(body, stroke(AppColors.ink, 3));
    canvas.drawPath(Path()..moveTo(12, 22)..lineTo(60, 58)..lineTo(108, 22), stroke(AppColors.ink, 3));
    final dot = Paint()..color = AppColors.ink;
    canvas.drawCircle(const Offset(44, 62), 3.6, dot);
    canvas.drawCircle(const Offset(76, 62), 3.6, dot);
    canvas.drawPath(Path()..moveTo(54, 70)..quadraticBezierTo(60, 76, 66, 70), stroke(AppColors.ink, 3));
    final blush = Paint()..color = const Color(0xFFF6B7A8);
    canvas.drawOval(Rect.fromCenter(center: const Offset(36, 70), width: 10, height: 6), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(84, 70), width: 10, height: 6), blush);
    final sparkle = stroke(stamp, 2.5);
    canvas
      ..drawLine(const Offset(6, 10), const Offset(10, 14), sparkle)
      ..drawLine(const Offset(14, 4), const Offset(15, 9), sparkle)
      ..drawLine(const Offset(2, 22), const Offset(7, 23), sparkle);
  }

  @override
  bool shouldRepaint(_EnvelopeFriendPainter old) => old.stamp != stamp;
}
