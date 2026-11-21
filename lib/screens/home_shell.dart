import 'package:flutter/material.dart';

import '../theme.dart';
import 'diary/note_screen.dart';
import 'journal/journal_screen.dart';
import 'stamps/collect_screen.dart';
import 'stamps/collections_screen.dart';
import 'today/today_screen.dart';
import 'vlog/vlog_camera_screen.dart';
import 'vlog/vlog_screen.dart';

/// Holds the four tabs (Today, Journal, Reel, Stamps), the floating bar that
/// switches between them, and the round + button that adds anything.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _tabs = [
    (Icons.wb_sunny_outlined, Icons.wb_sunny_rounded, 'Today'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Journal'),
    (Icons.videocam_outlined, Icons.videocam_rounded, 'Day reel'),
    (Icons.local_post_office_outlined, Icons.local_post_office_rounded, 'Stamps'),
  ];

  /// The + button: on Reel it opens the camera straight away, on Stamps
  /// the stamp camera; elsewhere it asks what to add.
  Future<void> _add() async {
    Widget? page = switch (_tab) {
      2 => const VlogCameraScreen(),
      3 => const CollectScreen(),
      _ => null,
    };
    page ??= await showModalBottomSheet<Widget>(
      context: context,
      builder: (context) {
        final t = context.dt;
        Widget row(IconData icon, String title, String sub, Widget to) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: t.text),
              ),
              title: Text(title, style: Fonts.sans(15, t.text, weight: FontWeight.w600)),
              subtitle: Text(sub, style: Fonts.sans(12, t.muted)),
              onTap: () => Navigator.pop(context, to),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Add to today', style: Fonts.serif(24, t.text)),
              ),
              row(Icons.edit_outlined, 'Write a note', 'Words, photos, a mood, #tags', const NoteScreen()),
              row(Icons.videocam_outlined, 'Record a clip', 'A few seconds for your day reel', const VlogCameraScreen()),
              row(Icons.local_post_office_outlined, 'Collect a stamp', 'A place or moment worth keeping',
                  const CollectScreen()),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (page == null || !mounted) return;
    final to = page;
    Navigator.push(context, MaterialPageRoute(builder: (_) => to));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final actionLabel = switch (_tab) {
      2 => 'Record a clip',
      3 => 'Collect a stamp',
      _ => 'Add to today',
    };
    return Scaffold(
      body: Stack(
        children: [
          // IndexedStack keeps each tab alive, so switching back doesn't reset it.
          IndexedStack(
            index: _tab,
            children: [const TodayScreen(), const JournalScreen(), VlogScreen(active: _tab == 2), const CollectionsScreen()],
          ),
          // A soft fade so content slides under the bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 130,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [t.bg.withValues(alpha: 0), t.bg],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.paddingOf(context).bottom + 18,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: t.surf,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: t.border),
                      boxShadow: [BoxShadow(color: t.shadow, blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < _tabs.length; i++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: i == _tab,
                              label: _tabs[i].$3,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _tab = i),
                                child: Center(
                                  // The open tab is simply darker, with no shape behind it.
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(i == _tab ? _tabs[i].$2 : _tabs[i].$1,
                                          size: 20, color: i == _tab ? t.text : t.muted),
                                      const SizedBox(height: 3),
                                      Text(_tabs[i].$3,
                                          style: Fonts.sans(10, i == _tab ? t.text : t.muted,
                                              weight: i == _tab ? FontWeight.w700 : FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: actionLabel,
                  child: Material(
                    color: t.fabBg,
                    shape: const CircleBorder(),
                    elevation: 0,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _add,
                      child: SizedBox(width: 60, height: 60, child: Icon(Icons.add_rounded, size: 26, color: t.fabFg)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
