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
    required this.sargamShuddhColor,
    required this.sargamShuddhBg,
    required this.sargamKomalColor,
    required this.sargamTivraColor,
    required this.trimHandleColor,
  });
}

// ─── Available palettes ────────────────────────────────────────────────

const indigoPalette = AppPalette(
  brightness:       Brightness.dark,
  seedColor:        Color(0xFF6366F1),
  scaffoldBg:       Color(0xFF0F0F14),
  cardBg:           Color(0xFF1A1A24),
  graphBg:          Color(0xFF12121A),
  tonicTint:        Color(0xFF6699CC),
  tooltipBg:        Color(0xFF2A2A3A),
  playheadColor:    Color(0xFFEF4444),
  bassColor:        Color(0xFFFF6B35),
  otherColor:       Color(0xFF48BFE3),
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
  sargamShuddhColor: Color(0xFF334155),
  sargamShuddhBg:    Color(0x15000000),
  sargamKomalColor:  Color(0xFF6482A6),
  sargamTivraColor:  Color(0xFFC25B64),
  trimHandleColor:  Color(0xFF334155),
);

// ─── Active palette — change this one line to switch ───────────────────
const appPalette = minimalistPalette;
