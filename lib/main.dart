import 'package:flutter/material.dart';
import 'data/letter_store.dart';
import 'screens/album_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LetterStore.instance.load(); // read saved letters before showing the album
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
      home: const AlbumScreen(),
    );
  }
}
