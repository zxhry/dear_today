import 'package:flutter/material.dart';
import 'data/letter_store.dart';
import 'data/settings_store.dart';
import 'data/tomorrow_store.dart';
import 'security/app_lock.dart';
import 'security/vault.dart';
import 'services/reminders.dart';
import 'screens/home_shell.dart';
import 'theme.dart';
import 'services/day_clock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsStore.instance.load();
  await Vault.instance.open(); // get the encryption key from the phone's Keystore
  await LetterStore.instance.load(); // read saved letters before showing the album
  await TomorrowStore.instance.load();
  AppLock.instance.lockIfEnabled(); // start locked if app lock is on
  DayClock.instance.start(); // refresh "today" at midnight and on return
  try {
    await Reminders.init(); // plan the next daily reminders
  } catch (e) {
    debugPrint('Reminders unavailable: $e'); // the app still works without them
  }
  runApp(const DearTodayApp());
}

class DearTodayApp extends StatefulWidget {
  const DearTodayApp({super.key});

  @override
  State<DearTodayApp> createState() => _DearTodayAppState();
}

class _DearTodayAppState extends State<DearTodayApp> {
  final _settings = SettingsStore.instance;
  late String _look = _lookOf();

  // Only changes to these need a full redraw.
  String _lookOf() => '${_settings.ink}-${_settings.paper}-${_settings.textSize}-${_settings.signOff}';

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

  void _onSettings() {
    final look = _lookOf();
    if (look == _look) return;
    _look = look;
    setState(() {}); // new theme for MaterialApp
    // Many screens are built once and reused, so ask every part of the app
    // to redraw with the new ink, paper and text size (keeps all state).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void redraw(Element e) {
        e.markNeedsBuild();
        e.visitChildren(redraw);
      }
      (context as Element).visitChildren(redraw);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dear Today',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Measure the screen once so text can fit narrower phones.
      builder: (context, child) {
        AppText.fitToWidth(MediaQuery.sizeOf(context).width);
        return AppLockGate(child: child!); // the lock sits on top of every screen
      },
      home: const HomeShell(),
    );
  }
}
