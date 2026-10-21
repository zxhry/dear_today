import 'package:flutter/material.dart';

import '../data/letter_store.dart';
import '../models/letter.dart';
import '../theme.dart';
import '../utils/dates.dart';
import '../widgets/buttons.dart';
import '../widgets/stamp.dart';
import '../widgets/stamp_picture.dart';
import 'letter_screen.dart';
import 'write_photo_screen.dart';

/// A month grid: every day with a letter shows a tiny stamp.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _weekdayLabels = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  static const _tilts = [-3.0, 2.0, -1.5, 2.5, -2.0, 1.0];

  final store = LetterStore.instance;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int by) => setState(() {
        _month = DateTime(_month.year, _month.month + by);
        // Select today when coming back to this month, otherwise the 1st.
        _selected = _isCurrentMonth ? dayOnly(DateTime.now()) : _month;
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final monthLetters = store.inMonth(_month.year, _month.month);
        final streak = store.streak;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              // Month title with arrows.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.chevron_left,
                      tooltip: 'Previous month',
                      onTap: () => _shiftMonth(-1),
                    ),
                    Expanded(
                      child: Text(monthYear(_month), textAlign: TextAlign.center, style: AppText.hand(32)),
                    ),
                    _RoundButton(
                      icon: Icons.chevron_right,
                      tooltip: 'Next month',
                      onTap: _isCurrentMonth ? null : () => _shiftMonth(1),
                    ),
                  ],
                ),
              ),
              // Little badges.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  _Badge('${monthLetters.length} ${monthLetters.length == 1 ? 'letter' : 'letters'} sealed'),
                  if (streak > 0 && _isCurrentMonth) _Badge('$streak-day streak'),
                ],
              ),
              const SizedBox(height: 14),
              // Weekday labels.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final w in _weekdayLabels)
                      Expanded(
                        child: Text(w,
                            textAlign: TextAlign.center,
                            style: AppText.body(11, weight: FontWeight.w800, color: AppColors.inkSoft)
                                .copyWith(letterSpacing: 1)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // The month grid.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MonthGrid(
                  month: _month,
                  selected: _selected,
                  lettersFor: store.forDay,
                  tilts: _tilts,
                  onSelect: (day) => setState(() => _selected = day),
                ),
              ),
              const SizedBox(height: 16),
              // What's on the selected day.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _DayCard(day: _selected, letters: store.forDay(_selected)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final List<Letter> Function(DateTime) lettersFor;
  final List<double> tilts;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.lettersFor,
    required this.tilts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday % 7; // Sunday first
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = dayOnly(DateTime.now());

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: leadingBlanks + daysInMonth,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 62,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, i) {
        if (i < leadingBlanks) return const SizedBox.shrink();
        final day = DateTime(month.year, month.month, i - leadingBlanks + 1);
        final letters = lettersFor(day);
        final isFuture = day.isAfter(today);
        return _DayCell(
          day: day,
          letters: letters,
          isToday: sameDay(day, today),
          isFuture: isFuture,
          isSelected: sameDay(day, selected),
          tilt: tilts[day.day % tilts.length],
          onTap: isFuture ? null : () => onSelect(day),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final List<Letter> letters;
  final bool isToday;
  final bool isFuture;
  final bool isSelected;
  final double tilt;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.letters,
    required this.isToday,
    required this.isFuture,
    required this.isSelected,
    required this.tilt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLetter = letters.isNotEmpty;
    final label = '${weekdayName(day)} ${day.day} ${monthName(day)}'
        '${hasLetter ? ', ${letters.length} ${letters.length == 1 ? 'letter' : 'letters'}' : ''}';

    final Widget content;
    if (hasLetter) {
      final newest = letters.first;
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          // One stamp per day showing the latest letter. Tap the day to see
          // every letter from it in the card below.
          StampFrame(
            holeRadius: 1.9,
            tilt: tilt,
            child: SizedBox(
              width: 32,
              height: 40,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StampPicture(photoPath: newest.photoPath, doodle: newest.doodle, iconSize: 16),
                  // Day number on a small white tag, readable over any photo.
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      // Shrinks to fit instead of wrapping, even with large
                      // phone text sizes. (The full date is still read out
                      // by screen readers through the cell's label.)
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${day.day}', maxLines: 1, softWrap: false, style: AppText.hand(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      content = Container(
        width: 36,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          // Past days without a letter get a faint outline: an empty slot.
          border: isFuture ? null : Border.all(color: const Color(0xFFCBD2E1), width: 1.5),
        ),
        child: Text(
          '${day.day}',
          style: AppText.body(
            14,
            weight: isToday ? FontWeight.w800 : FontWeight.w700,
            color: isToday ? AppColors.accent : (isFuture ? const Color(0xFF5F6985) : AppColors.inkSoft),
          ),
        ),
      );
    }

    return Semantics(
      button: onTap != null,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isSelected ? AppColors.accent : Colors.transparent, width: 2.5),
            ),
            child: ExcludeSemantics(child: content),
          ),
        ),
      ),
    );
  }
}

/// The card under the grid: the selected day's letters, or an invitation to write.
class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<Letter> letters;
  const _DayCard({required this.day, required this.letters});

  @override
  Widget build(BuildContext context) {
    final isToday = sameDay(day, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.12), offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${stampDate(day)}${isToday ? ' · Today' : ''}'.toUpperCase(),
            style: AppText.body(11, weight: FontWeight.w800, color: AppColors.inkSoft).copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          if (letters.isEmpty) ...[
            Text(isToday ? 'Nothing sealed yet today' : 'No letter this day', style: AppText.hand(24)),
            if (isToday) ...[
              const SizedBox(height: 12),
              ChunkyButton(
                label: 'Write to today',
                icon: Icons.edit_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WritePhotoScreen(draft: LetterDraft(date: DateTime.now()))),
                ),
              ),
            ],
          ] else
            for (final letter in letters) _LetterRow(letter: letter),
        ],
      ),
    );
  }
}

class _LetterRow extends StatelessWidget {
  final Letter letter;
  const _LetterRow({required this.letter});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LetterScreen(letter: letter))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            StampFrame(
              holeRadius: 2.6,
              tilt: -3,
              child: SizedBox(
                width: 52,
                height: 62,
                child: StampPicture(photoPath: letter.photoPath, doodle: letter.doodle, iconSize: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(letter.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.hand(22)),
                  const SizedBox(height: 2),
                  Text(
                    letter.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(13, weight: FontWeight.w500, color: const Color(0xFF3A4668)),
                  ),
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

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _RoundButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.white.withValues(alpha: 0.5),
        side: BorderSide(color: onTap == null ? const Color(0xFFB8C1D6) : AppColors.ink, width: 1.5),
      ),
      icon: Icon(icon, color: onTap == null ? const Color(0xFFB8C1D6) : AppColors.ink),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Text(text, style: AppText.body(12, weight: FontWeight.w800)),
    );
  }
}
