import 'package:flutter/material.dart';

/// Central color palette for the entire application.
///
/// To try a different color scheme, edit the values below or create
/// an alternative [AppPalette] instance and assign it to [appPalette].
class AppPalette {
  final Brightness brightness;
  final Color seedColor;
  final Color scaffoldBg;
  final Color cardBg;
  final Color graphBg;
  final Color tonicTint;
  final Color tooltipBg;
  final Color playheadColor;
  final Color bassColor;
  final Color otherColor;
  final Color bassHighlightColor;
  final Color otherHighlightColor;
  final Color vocalHighlightColor;
  final Color hoverRowBg;
  final Color hoverLabelColor;
  final Color hoverLabelBg;
  final Color sargamShuddhColor;
  final Color sargamShuddhBg;
  final Color sargamKomalColor;
  final Color sargamTivraColor;
  final Color trimHandleColor;

  const AppPalette({
    required this.brightness,
    required this.seedColor,
    required this.scaffoldBg,
    required this.cardBg,
    required this.graphBg,
    required this.tonicTint,
    required this.tooltipBg,
    required this.playheadColor,
    required this.bassColor,
    required this.otherColor,
    required this.bassHighlightColor,
    required this.otherHighlightColor,
    required this.vocalHighlightColor,
    required this.hoverRowBg,
    required this.hoverLabelColor,
    required this.hoverLabelBg,
    required this.sargamShuddhColor,
    required this.sargamShuddhBg,
    required this.sargamKomalColor,
    required this.sargamTivraColor,
    required this.trimHandleColor,
  });
}

// --- Available palettes ------------------------------------------------

const darkPalette = AppPalette(
  brightness:       Brightness.dark,
  seedColor:        Color(0xFF14B8A6),
  scaffoldBg:       Color(0xFF000000),
  cardBg:           Color(0xFF000000),
  graphBg:          Color(0xFF111413),
  tonicTint:        Color(0xFF6699CC),
  tooltipBg:        Color(0xFF262C2B),
  playheadColor:    Color(0xFFEF4444),
  bassColor:        Color(0xFFFF6B35),
  otherColor:       Color(0xFF48BFE3),
  bassHighlightColor: Color(0xFFFF3300),
  otherHighlightColor: Color(0xFF0066CC),
  vocalHighlightColor: Color(0xFFFF9800), // Bright orange for vocal highlights
  hoverRowBg: Color(0x2614B8A6), // Teal at 15% opacity (more visible)
  hoverLabelColor: Color(0xFF5EEAD4), // Light teal for dark theme
  hoverLabelBg: Color(0x4D14B8A6), // Teal at 30% opacity (more visible)
  sargamShuddhColor: Color(0xFFE0E0E0),
  sargamShuddhBg:    Color(0x22FFFFFF),
  sargamKomalColor:  Color(0xFF90CAF9),
  sargamTivraColor:  Color(0xFFEF9A9A),
  trimHandleColor:  Color(0xFFFFFFFF),
);

const minimalistPalette = AppPalette(
  brightness:       Brightness.light,
  seedColor:        Color(0xFF64748B),
  scaffoldBg:       Color(0xFFF8FAFC),
  cardBg:           Color(0xFFFFFFFF),
  graphBg:          Color(0xFFF1F5F9),
  tonicTint:        Color(0xFF94A3B8),
  tooltipBg:        Color(0xFFFFFFFF),
  playheadColor:    Color(0xFFE11D48),
  bassColor:        Color(0xFFD97756),
  otherColor:       Color(0xFF5B9E8F),
  bassHighlightColor: Color(0xFFDD3300),
  otherHighlightColor: Color(0xFF0055AA),
  vocalHighlightColor: Color(0xFFFF9800), // Bright orange for vocal highlights
  hoverRowBg: Color(0x3364748B), // Slate at 20% opacity (more visible)
  hoverLabelColor: Color(0xFFFFFFFF), // White text for light theme
  hoverLabelBg: Color(0xFF3B82F6), // Bright blue background (solid)
  sargamShuddhColor: Color(0xFF334155),
  sargamShuddhBg:    Color(0x15000000),
  sargamKomalColor:  Color(0xFF6482A6),
  sargamTivraColor:  Color(0xFFC25B64),
  trimHandleColor:  Color(0xFF334155),
);

// --- Active palette ------------------------------------------------------
// Kept in sync with the current theme mode / system brightness by MyApp's
// build method in main.dart (CustomPainters and other non-widget code that
// can't easily reach Theme.of(context) read this global directly).
AppPalette appPalette = minimalistPalette;
