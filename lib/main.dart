import 'package:flutter/material.dart';
import 'screens/album_screen.dart';
import 'theme.dart';

void main() {
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
