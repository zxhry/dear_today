import 'package:flutter/material.dart';

import '../data/letter_store.dart';
import '../models/letter.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/buttons.dart';
import '../widgets/letter_stamp.dart';
import '../widgets/stamp.dart';
import 'letter_screen.dart';
import 'write_photo_screen.dart';

/// Home screen: one day's letters shown as stamps. Switch days with the
/// arrows or by swiping. (The Calendar tab shows the whole month.)
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  // Right-column stamps get as much tilt as the others (indices 2, 5, 8).
  static const _tilts = [-2.0, 1.5, 2.2, 1.8, -1.5, -2.2, -1.8, 2.0, 1.8];

  final store = LetterStore.instance;
  DateTime _day = dayOnly(DateTime.now());

  bool get _isToday => sameDay(_day, DateTime.now());

  void _shiftDay(int by) {
    final next = DateTime(_day.year, _day.month, _day.day + by);
    if (next.isAfter(dayOnly(DateTime.now()))) return; // no future days
    setState(() => _day = next);
  }

  void _openLetter(Letter letter) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LetterScreen(letter: letter)),
      );

  void _writeToday() {
    setState(() => _day = dayOnly(DateTime.now())); // show today, where the new letter will appear
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WritePhotoScreen(draft: LetterDraft(date: DateTime.now()))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever a letter is sealed.
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final letters = store.forDay(_day);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const _Header(),
                _DaySwitcher(
                  day: _day,
                  isToday: _isToday,
                  count: letters.length,
                  onPrev: () => _shiftDay(-1),
                  onNext: _isToday ? null : () => _shiftDay(1),
                ),
                Expanded(
                  // Swipe right for the day before, left for the day after.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v > 300) _shiftDay(-1);
                      if (v < -300) _shiftDay(1);
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: letters.isEmpty
                          ? _EmptyDay(key: ValueKey('empty-$_day'), isToday: _isToday, day: _day)
                          : GridView.builder(
                              key: ValueKey('day-$_day'),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: letters.length,
                              itemBuilder: (context, i) => LetterStamp(
                                letter: letters[i],
                                tilt: _tilts[i % _tilts.length],
                                onTap: () => _openLetter(letters[i]),
                              ),
                            ),
                    ),
                  ),
                ),
                // Writing is only for today, so the button only shows on today's page.
                if (_isToday)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: ChunkyButton(
                      label: 'Write to today',
                      icon: Icons.edit_outlined,
                      onTap: _writeToday,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.mail_outline_rounded, size: 34, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(child: Text('Dear Today,', style: AppText.hand(38))),
        ],
      ),
    );
  }
}

class _DaySwitcher extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final int count;
  final VoidCallback onPrev;
  final VoidCallback? onNext; // null = can't go into the future

  const _DaySwitcher({
    required this.day,
    required this.isToday,
    required this.count,
    required this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final yesterday = sameDay(day, DateTime.now().subtract(const Duration(days: 1)));
    final tag = isToday ? 'Today · ' : (yesterday ? 'Yesterday · ' : '');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, color: AppColors.ink),
          ),
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${weekdayName(day)}, ${day.day} ${shortMonth(day)}', style: AppText.hand(26)),
                ),
                const SizedBox(height: 2),
                Text('$tag$count ${count == 1 ? 'letter' : 'letters'} sealed',
                    style: AppText.body(13, color: AppColors.inkSoft)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: onNext,
            icon: Icon(Icons.chevron_right, color: onNext == null ? const Color(0xFFB8C1D6) : AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final bool isToday;
  final DateTime day;
  const _EmptyDay({super.key, required this.isToday, required this.day});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StampFrame(
              tilt: -3,
              child: Container(
                width: 90,
                height: 110,
                color: const Color(0xFFF3F6FB),
                alignment: Alignment.center,
                child: const Icon(Icons.add_a_photo_outlined, size: 34, color: AppColors.inkSoft),
              ),
            ),
            const SizedBox(height: 20),
            Text(isToday ? 'Today\'s stamp is waiting' : 'No letter on ${weekdayName(day)}',
                textAlign: TextAlign.center, style: AppText.hand(26)),
            const SizedBox(height: 6),
            Text(
              isToday ? 'Tap "Write to today" to seal today\'s first letter.' : 'This day\'s page is blank.',
              textAlign: TextAlign.center,
              style: AppText.body(14, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
