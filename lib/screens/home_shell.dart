import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../data/tomorrow_store.dart';
import '../theme.dart';
import 'album_screen.dart';
import 'calendar_screen.dart';
import 'mailbox_screen.dart';
import 'me_screen.dart';
import '../services/day_clock.dart';
import '../widgets/tour_overlay.dart';

/// Holds the four tabs and the bottom bar that switches between them.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final _settings = SettingsStore.instance;
  late bool _touring = !_settings.tourSeen;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettings);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    super.dispose();
  }

  // "Replay the tour" in the Me tab turns the tour back on.
  void _onSettings() {
    final touring = !_settings.tourSeen;
    if (touring != _touring) {
      setState(() {
        _touring = touring;
        if (touring) _tab = 0; // the tour starts on the Letters page
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _app(context),
        if (_touring) Positioned.fill(child: TourOverlay(onFinish: () => _settings.setTourSeen(true))),
      ],
    );
  }

  Widget _app(BuildContext context) {
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
          listenable: Listenable.merge([TomorrowStore.instance, DayClock.instance]),
          builder: (context, _) {
            final mail = TomorrowStore.instance.arrived.length;
            return NavigationBar(
              key: TourTargets.nav, // the tour points at its tabs
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
