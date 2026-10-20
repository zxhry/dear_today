import 'package:flutter/material.dart';

import '../data/tomorrow_store.dart';
import '../theme.dart';
import 'album_screen.dart';
import 'calendar_screen.dart';
import 'mailbox_screen.dart';
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
        children: const [AlbumScreen(), CalendarScreen(), MailboxScreen(), MeScreen()],
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
        // Rebuild when mail arrives, so the Mailbox tab can show a badge.
        child: ListenableBuilder(
          listenable: TomorrowStore.instance,
          builder: (context, _) {
            final mail = TomorrowStore.instance.arrived.length;
            return NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Letters',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Calendar',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: mail > 0,
                    label: Text('$mail'),
                    backgroundColor: AppColors.accent,
                    child: const Icon(Icons.markunread_mailbox_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: mail > 0,
                    label: Text('$mail'),
                    backgroundColor: AppColors.accent,
                    child: const Icon(Icons.markunread_mailbox),
                  ),
                  label: 'Mailbox',
                  tooltip: mail > 0 ? 'Mailbox, $mail new' : 'Mailbox',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Me',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
