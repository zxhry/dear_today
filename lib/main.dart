import 'package:flutter/material.dart';
import 'data/letter_store.dart';
import 'data/settings_store.dart';
import 'data/tomorrow_store.dart';
import 'security/app_lock.dart';
import 'security/vault.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsStore.instance.load();
  await Vault.instance.open(); // get the encryption key from the phone's Keystore
  await LetterStore.instance.load(); // read saved letters before showing the album
  await TomorrowStore.instance.load();
  AppLock.instance.lockIfEnabled(); // start locked if app lock is on
  runApp(const DearTodayApp());
}

class DearTodayApp extends StatelessWidget {
  const DearTodayApp({super.key});

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
