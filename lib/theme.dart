import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All of Dear Today's colours live here, so the whole look can be
/// changed from one place.
class AppColors {
  // Ink (accent) and paper (background) can be changed in the Me tab.
  static Color accent = inks.first.color;
  static Color paper = papers.first.color;

  static const ink = Color(0xFF22305A); // navy "ink" for text and lines
  static const inkSoft = Color(0xFF4A5577); // secondary text
  static const white = Color(0xFFFFFFFF);
  static const divider = Color(0xFF9AA6C4);

  // Soft tones for quiet outlines and icons (used on all the gentler pages).
  static const line = Color(0xFFD5DAE6); // light outline for buttons, tiles, circles
  static const edge = Color(0x1222305A); // barely-there card edge
  static const iconSoft = Color(0xFF7C87A6); // grey-blue icons

  // Soft photo-placeholder tints for the stamps.
  static const sky = Color(0xFFCFE3EF);
  static const peach = Color(0xFFF6D7C8);
  static const lavender = Color(0xFFD9DDF2);
  static const butter = Color(0xFFF7E7B4);
  static const sage = Color(0xFFD6E6D2);

  static const inks = [
    NamedColor('Coral', Color(0xFFC24E3B)),
    NamedColor('Ocean', Color(0xFF3E6FB0)),
    NamedColor('Leaf', Color(0xFF4F7F40)),
    NamedColor('Plum', Color(0xFF8A56A8)),
  ];
  static const papers = [
    NamedColor('Cream', Color(0xFFF7EEE4)),
    NamedColor('Sky', Color(0xFFE9F0F7)),
    NamedColor('Mint', Color(0xFFEEF4EA)),
    NamedColor('Lilac', Color(0xFFF3EDF7)),
  ];
}

class NamedColor {
  final String name;
  final Color color;
  const NamedColor(this.name, this.color);
}

/// Handwritten font for titles, friendly rounded font for body text.
class AppText {
  /// The designs were made for a 390-wide screen. On narrower phones,
  /// text shrinks in proportion (never below 88%) so layouts keep their
  /// breathing room. Set once from the screen width in main.dart.
  static double fit = 1;
  static const designWidth = 390.0;

  static void fitToWidth(double width) => fit = (width / designWidth).clamp(0.88, 1.0);

  /// Extra scale for letter text only (Small / Default / Large in the Me tab).
  static double letterScale = 1;
  static const letterScales = [0.88, 1.0, 1.15];
  static const letterScaleNames = ['Small', 'Default', 'Large'];

  /// The text of a letter: body font, roomy lines, follows letter text size.
  static TextStyle letter({Color color = AppColors.ink}) =>
      body(15 * letterScale, weight: FontWeight.w500, color: color).copyWith(height: 2);

  static TextStyle hand(double size, {Color color = AppColors.ink}) => GoogleFonts.gaegu(
      fontSize: size * fit, fontWeight: FontWeight.w700, color: color, height: 1);

  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w600, Color color = AppColors.ink}) =>
      GoogleFonts.nunito(fontSize: size * fit, fontWeight: weight, color: color);
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
