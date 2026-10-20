import 'package:flutter/material.dart';
import '../theme.dart';

/// One day's letter. For now it holds sample data; later it will be
/// saved in an encrypted database on the phone.
class Letter {
  final DateTime date;
  final String title;
  final Color tint; // placeholder colour until real photos exist
  final IconData icon; // doodle shown when there's no photo

  const Letter({
    required this.date,
    required this.title,
    required this.tint,
    required this.icon,
  });
}

/// Sample letters so the album isn't empty while we build.
final sampleLetters = <Letter>[
  Letter(date: DateTime(2026, 10, 20), title: 'First rain', tint: AppColors.sky, icon: Icons.water_drop_outlined),
  Letter(date: DateTime(2026, 10, 19), title: 'Milo break', tint: AppColors.peach, icon: Icons.local_cafe_outlined),
  Letter(date: DateTime(2026, 10, 18), title: 'Library day', tint: AppColors.lavender, icon: Icons.menu_book_outlined),
  Letter(date: DateTime(2026, 10, 17), title: 'Sunny walk', tint: AppColors.butter, icon: Icons.wb_sunny_outlined),
  Letter(date: DateTime(2026, 10, 16), title: 'Little bloom', tint: AppColors.sage, icon: Icons.local_florist_outlined),
  Letter(date: DateTime(2026, 10, 15), title: 'Late night', tint: AppColors.lavender, icon: Icons.nightlight_outlined),
  Letter(date: DateTime(2026, 10, 14), title: 'Family call', tint: AppColors.peach, icon: Icons.favorite_border),
  Letter(date: DateTime(2026, 10, 13), title: 'Study break', tint: AppColors.sky, icon: Icons.local_cafe_outlined),
  Letter(date: DateTime(2026, 10, 12), title: 'Golden hour', tint: AppColors.butter, icon: Icons.wb_sunny_outlined),
];
