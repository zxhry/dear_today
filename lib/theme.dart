import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dear Today's colours ("soft plum"), for the light and the dark theme.
///
/// Screens read them with `context.dt`, so every colour follows the theme
/// chosen in Settings (Light, Dark or System).
@immutable
class DT extends ThemeExtension<DT> {
  final Color bg; // page background
  final Color surf; // cards, buttons, bars
  final Color surf2; // selected tab, small icon tiles
  final Color border; // quiet outlines
  final Color text; // main text
  final Color muted; // secondary text
  final Color accent; // tab underline, record ring, switches
  final Color fabBg; // main buttons (Save, Share, the round + button)
  final Color fabFg; // text and icons on main buttons
  final Color ink; // postmark ink
  final Color dim; // empty slots, inactive outlines
  final Color stampPaper; // the paper around a stamp's photo
  final Color shadow;
  final Color seg1, seg2, seg3; // storage bar: stamps, diary, vlog

  const DT({
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.fabBg,
    required this.fabFg,
    required this.ink,
    required this.dim,
    required this.stampPaper,
    required this.shadow,
    required this.seg1,
    required this.seg2,
    required this.seg3,
  });

  static const light = DT(
    bg: Color(0xFFFBF7F5),
    surf: Color(0xFFFFFFFF),
    surf2: Color(0xFFF6E6DF),
    border: Color(0xFFEDE3DF),
    text: Color(0xFF190019),
    muted: Color(0xFF6B5468),
    accent: Color(0xFF854F6C),
    fabBg: Color(0xFF2B124C),
    fabFg: Color(0xFFFFFFFF),
    ink: Color(0xFF2B124C),
    dim: Color(0xFFDFCBCB),
    stampPaper: Color(0xFFFFFFFF),
    shadow: Color(0x14190019),
    seg1: Color(0xFF2B124C),
    seg2: Color(0xFF854F6C),
    seg3: Color(0xFFDFB6B2),
  );

  static const dark = DT(
    bg: Color(0xFF190019),
    surf: Color(0xFF241A2A),
    surf2: Color(0xFF3A2B40),
    border: Color(0xFF33263A),
    text: Color(0xFFF5EAE4),
    muted: Color(0xFFC9B3B4),
    accent: Color(0xFFDFB6B2),
    fabBg: Color(0xFFFBE4D8),
    fabFg: Color(0xFF190019),
    ink: Color(0xFFDFB6B2),
    dim: Color(0xFF4A3A50),
    stampPaper: Color(0xFFFBE4D8),
    shadow: Color(0x73000000),
    seg1: Color(0xFFFBE4D8),
    seg2: Color(0xFFB9799A),
    seg3: Color(0xFF6E4A75),
  );

  /// Soft photo-placeholder tones (used before a photo has loaded).
  static const tones = [
    Color(0xFF9FB4C7),
    Color(0xFFD9A77C),
    Color(0xFF8EA68B),
    Color(0xFFC9B79C),
    Color(0xFF7D8FA8),
    Color(0xFFD58C7A),
    Color(0xFFB7C4A0),
    Color(0xFFA39BC2),
  ];

  /// The viewfinder colour while the camera is starting.
  static const viewfinder = Color(0xFF3B2A4A);

  @override
  DT copyWith() => this;

  @override
  DT lerp(ThemeExtension<DT>? other, double t) {
    if (other is! DT) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return DT(
      bg: c(bg, other.bg),
      surf: c(surf, other.surf),
      surf2: c(surf2, other.surf2),
      border: c(border, other.border),
      text: c(text, other.text),
      muted: c(muted, other.muted),
      accent: c(accent, other.accent),
      fabBg: c(fabBg, other.fabBg),
      fabFg: c(fabFg, other.fabFg),
      ink: c(ink, other.ink),
      dim: c(dim, other.dim),
      stampPaper: c(stampPaper, other.stampPaper),
      shadow: c(shadow, other.shadow),
      seg1: c(seg1, other.seg1),
      seg2: c(seg2, other.seg2),
      seg3: c(seg3, other.seg3),
    );
  }
}

extension DTContext on BuildContext {
  DT get dt => Theme.of(this).extension<DT>()!;
}

/// The three fonts: a serif for titles, Inter for everything else, and a
/// typewriter-style mono for labels, times and diary text.
class Fonts {
  static TextStyle serif(double size, Color color) => GoogleFonts.newsreader(
      fontSize: size, fontWeight: FontWeight.w500, color: color, height: 1.15, letterSpacing: -0.2);

  static TextStyle sans(double size, Color color, {FontWeight weight = FontWeight.w400, double? height}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle mono(double size, Color color, {double spacing = 0, double? height}) =>
      GoogleFonts.ibmPlexMono(
          fontSize: size, fontWeight: FontWeight.w500, color: color, letterSpacing: spacing, height: height);

  /// Small capital labels like "DEAR TODAY" or "EARLIER".
  static TextStyle label(Color color) => mono(11.5, color, spacing: 1.4);
}

ThemeData buildTheme(Brightness brightness) {
  final t = brightness == Brightness.dark ? DT.dark : DT.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true, fontFamily: GoogleFonts.inter().fontFamily);
  return base.copyWith(
    scaffoldBackgroundColor: t.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: brightness,
      surface: t.surf,
      primary: t.fabBg,
      onPrimary: t.fabFg,
    ),
    textTheme: base.textTheme.apply(bodyColor: t.text, displayColor: t.text),
    dialogTheme: DialogThemeData(backgroundColor: t.surf, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surf,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: t.dim,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.fabBg,
      contentTextStyle: Fonts.sans(14, t.fabFg),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accent : t.dim),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.accent),
    textSelectionTheme: TextSelectionThemeData(cursorColor: t.accent, selectionHandleColor: t.accent),
    extensions: [t],
  );
}
