import 'package:flutter/material.dart';

import '../theme.dart';
import 'diary/diary_screen.dart';
import 'diary/note_screen.dart';
import 'settings/settings_screen.dart';
import 'stamps/collect_screen.dart';
import 'stamps/collections_screen.dart';
import 'vlog/vlog_camera_screen.dart';
import 'vlog/vlog_screen.dart';

/// Holds the four tabs, the floating bar that switches between them, and
/// the round button beside it. The round button follows the tab: a new
/// note on Diary, the vlog camera on Vlog, the stamp camera everywhere else.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _tabs = [
    (Icons.folder_outlined, Icons.folder_rounded, 'Stamps'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Diary'),
    (Icons.videocam_outlined, Icons.videocam_rounded, 'Vlog'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  void _action() {
    final Widget page = switch (_tab) {
      1 => const NoteScreen(),
      2 => const VlogCameraScreen(),
      _ => const CollectScreen(),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.dt;
    final (actionIcon, actionLabel) = switch (_tab) {
      1 => (Icons.edit_outlined, 'New note'),
      2 => (Icons.videocam_outlined, 'Record a clip'),
      _ => (Icons.add_rounded, 'Collect a stamp'),
    };
    return Scaffold(
      body: Stack(
        children: [
          // IndexedStack keeps each tab alive, so switching back doesn't reset it.
          IndexedStack(
            index: _tab,
            children: const [CollectionsScreen(), DiaryScreen(), VlogScreen(), SettingsScreen()],
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
                    height: 64,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: t.surf,
                      borderRadius: BorderRadius.circular(32),
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
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: i == _tab ? t.surf2 : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(i == _tab ? _tabs[i].$2 : _tabs[i].$1,
                                        size: 22, color: i == _tab ? t.text : t.muted),
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
                      onTap: _action,
                      child: SizedBox(width: 64, height: 64, child: Icon(actionIcon, size: 26, color: t.fabFg)),
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
