import 'package:flutter/material.dart';

import '../theme.dart';
import 'album_screen.dart';
import 'calendar_screen.dart';
import 'me_screen.dart';

/// Holds the four tabs and the bottom bar that switches between them.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab alive, so switching back doesn't reset it.
      body: IndexedStack(
        index: _tab,
        children: const [
          AlbumScreen(),
          CalendarScreen(),
          _ComingSoon(
            icon: Icons.markunread_mailbox_outlined,
            title: 'Your mailbox',
            text: 'Monthly bundles of letters, and letters to tomorrow, will live here.',
          ),
          MeScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.accent.withValues(alpha: 0.12),
          labelTextStyle: WidgetStatePropertyAll(AppText.body(12, weight: FontWeight.w700)),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.inkSoft,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Letters',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.markunread_mailbox_outlined),
              selectedIcon: Icon(Icons.markunread_mailbox),
              label: 'Mailbox',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _ComingSoon({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.ink),
              const SizedBox(height: 16),
              Text(title, style: AppText.hand(32)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.inkSoft)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.ink, width: 1.5),
                ),
                child: Text('Coming soon', style: AppText.body(12, weight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
