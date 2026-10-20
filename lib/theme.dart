import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All of Dear Today's colours live here, so the whole look can be
/// changed from one place.
class AppColors {
  static const paper = Color(0xFFF7EEE4); // warm cream background
  static const ink = Color(0xFF22305A); // navy "ink" for text and lines
  static const inkSoft = Color(0xFF4A5577); // secondary text
  static const accent = Color(0xFFC24E3B); // coral stamp red
  static const white = Color(0xFFFFFFFF);
  static const divider = Color(0xFF9AA6C4);

  // Soft photo-placeholder tints for the stamps.
  static const sky = Color(0xFFCFE3EF);
  static const peach = Color(0xFFF6D7C8);
  static const lavender = Color(0xFFD9DDF2);
  static const butter = Color(0xFFF7E7B4);
  static const sage = Color(0xFFD6E6D2);
}

/// Handwritten font for titles, friendly rounded font for body text.
class AppText {
  static TextStyle hand(double size, {Color color = AppColors.ink}) =>
      GoogleFonts.gaegu(fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1);

  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w600, Color color = AppColors.ink}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color);
}

ThemeData buildTheme() {
  return ThemeData(
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      surface: AppColors.paper,
    ),
    fontFamily: GoogleFonts.nunito().fontFamily,
    useMaterial3: true,
  );
}
