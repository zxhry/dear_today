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

/// Home screen: one month of letters shown as a sheet of stamps.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  // Right-column stamps get as much tilt as the others (indices 2, 5, 8).
  static const _tilts = [-2.0, 1.5, 2.2, 1.8, -1.5, -2.2, -1.8, 2.0, 1.8];

  final store = LetterStore.instance;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int by) => setState(() => _month = DateTime(_month.year, _month.month + by));

  void _openLetter(Letter letter) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LetterScreen(letter: letter)),
      );

  void _writeToday() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WritePhotoScreen(draft: LetterDraft(date: DateTime.now()))),
      );

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever a letter is sealed.
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final letters = store.inMonth(_month.year, _month.month);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const _Header(),
                _MonthSwitcher(
                  month: _month,
                  count: letters.length,
                  onPrev: () => _shiftMonth(-1),
                  onNext: _isCurrentMonth ? null : () => _shiftMonth(1),
                ),
                Expanded(
                  child: letters.isEmpty
                      ? _EmptyMonth(isCurrent: _isCurrentMonth, month: _month)
                      : GridView.builder(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: ChunkyButton(label: 'Write to today', icon: Icons.edit_outlined, onTap: _writeToday),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const _BottomTabs(),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        children: [
          const Icon(Icons.mail_outline_rounded, size: 34, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(child: Text('Dear Today,', style: AppText.hand(38))),
          IconButton(
            tooltip: 'Search letters',
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.ink, width: 1.5),
            ),
            icon: const Icon(Icons.search, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final int count;
  final VoidCallback onPrev;
  final VoidCallback? onNext; // null = can't go into the future

  const _MonthSwitcher({required this.month, required this.count, required this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, color: AppColors.ink),
          ),
          Expanded(
            child: Column(
              children: [
                Text(monthYear(month), style: AppText.hand(26)),
                const SizedBox(height: 2),
                Text('$count ${count == 1 ? 'letter' : 'letters'} sealed',
                    style: AppText.body(13, color: AppColors.inkSoft)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: Icon(Icons.chevron_right, color: onNext == null ? const Color(0xFFB8C1D6) : AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  final bool isCurrent;
  final DateTime month;
  const _EmptyMonth({required this.isCurrent, required this.month});

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
            Text(isCurrent ? 'Your first stamp is waiting' : 'No letters in ${monthName(month)}',
                textAlign: TextAlign.center, style: AppText.hand(26)),
            const SizedBox(height: 6),
            Text(
              isCurrent
                  ? 'Tap "Write to today" to seal this month\'s first letter.'
                  : 'This page of your album is still blank.',
              textAlign: TextAlign.center,
              style: AppText.body(14, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomTabs extends StatelessWidget {
  const _BottomTabs();

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(AppText.body(12, weight: FontWeight.w700)),
      ),
      child: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.accent),
            label: 'Letters',
          ),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.markunread_mailbox_outlined), label: 'Mailbox'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Me'),
        ],
      ),
    );
  }
}
