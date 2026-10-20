import 'package:flutter/material.dart';
import '../models/letter.dart';
import '../theme.dart';
import '../widgets/letter_stamp.dart';

/// Home screen: this month's letters shown as a sheet of stamps.
class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  // A little hand-stuck wobble so the stamps don't look machine-placed.
  // Right-column stamps get as much tilt as the others (indices 2, 5, 8).
  static const _tilts = [-2.0, 1.5, 2.2, 1.8, -1.5, -2.2, -1.8, 2.0, 1.8];

  @override
  Widget build(BuildContext context) {
    final letters = sampleLetters;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            _MonthSwitcher(count: letters.length),
            Expanded(
              child: GridView.builder(
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
                  onTap: () => _comingSoon(context, 'Opening letters'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: _WriteButton(onTap: () => _comingSoon(context, 'Writing a letter')),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _BottomTabs(),
    );
  }

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is coming soon ✉')),
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
  final int count;
  const _MonthSwitcher({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () {},
            icon: const Icon(Icons.chevron_left, color: AppColors.ink),
          ),
          Expanded(
            child: Column(
              children: [
                Text('October 2026', style: AppText.hand(26)),
                const SizedBox(height: 2),
                Text('$count letters sealed',
                    style: AppText.body(13, color: AppColors.inkSoft)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () {},
            icon: const Icon(Icons.chevron_right, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _WriteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WriteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      // The solid navy shadow underneath gives it a chunky, stamp-like feel.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 4))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.white,
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: Text('Write to today', style: AppText.hand(24, color: AppColors.white)),
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
