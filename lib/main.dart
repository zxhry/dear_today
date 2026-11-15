import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/journal_store.dart';
import 'data/settings_store.dart';
import 'screens/home_shell.dart';
import 'security/app_lock.dart';
import 'security/vault.dart';
import 'services/day_clock.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The app stays upright. The vlog camera still records sideways clips
  // when you turn the phone, because the camera follows the phone itself.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SettingsStore.instance.load();
  await Vault.instance.open(); // get the encryption key from the phone's Keystore
  await JournalStore.instance.load(); // read stamps, diary and vlog before showing them
  AppLock.instance.lockIfEnabled(); // start locked if app lock is on
  DayClock.instance.start(); // refresh "today" at midnight and on return
  runApp(const DearTodayApp());
}

class DearTodayApp extends StatelessWidget {
  const DearTodayApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild when the theme setting changes.
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) => MaterialApp(
        title: 'Dear Today',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: SettingsStore.instance.themeMode,
        builder: (context, child) => AppLockGate(child: child!), // the lock sits on top of every screen
        home: const HomeShell(),
      ),
    );
  }
}
