import 'package:flutter/material.dart';

/// Central color palette for the entire application.
///
/// To try a different color scheme, edit the values below or create
/// an alternative [AppPalette] instance and assign it to [appPalette].
class AppPalette {
  // ─── Material theme seed ─────────────────────────────────────────────
  final Color seedColor;

  // ─── Dark theme surface overrides ────────────────────────────────────
  final Color darkScaffoldBg;
  final Color darkCardBg;

  // ─── Graph background ────────────────────────────────────────────────
  final Color darkGraphBg;
  final Color lightGraphBg;

  // ─── Tonic row highlight ─────────────────────────────────────────────
  final Color darkTonicTint;
  final Color lightTonicTint;

  // ─── Tooltip background ──────────────────────────────────────────────
  final Color darkTooltipBg;
  final Color lightTooltipBg;

  // ─── Playhead ────────────────────────────────────────────────────────
  final Color playheadColor;

  // ─── Instrument track colors ─────────────────────────────────────────
  final Color bassColor;
  final Color otherColor;

  // ─── Sargam note colors ──────────────────────────────────────────────
  final Color sargamShuddhColor;
  final Color sargamShuddhBg;
  final Color sargamKomalColor;
  final Color sargamTivraColor;

  // ─── Trim slider ─────────────────────────────────────────────────────
  final Color trimHandleColor;

  const AppPalette({
    required this.seedColor,
    required this.darkScaffoldBg,
    required this.darkCardBg,
    required this.darkGraphBg,
    required this.lightGraphBg,
    required this.darkTonicTint,
    required this.lightTonicTint,
    required this.darkTooltipBg,
    required this.lightTooltipBg,
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

/// Active palette — change this single reference to swap the entire color scheme.
const appPalette = AppPalette(
  seedColor:        Color(0xFF6366F1),  // indigo

  darkScaffoldBg:   Color(0xFF0F0F14),
  darkCardBg:       Color(0xFF1A1A24),

  darkGraphBg:      Color(0xFF12121A),
  lightGraphBg:     Color(0xFFF8F9FA),

  darkTonicTint:    Color(0xFF6699CC),
  lightTonicTint:   Color(0xFF336699),

  darkTooltipBg:    Color(0xFF2A2A3A),
  lightTooltipBg:   Color(0xFFE8E8EC),

  playheadColor:    Color(0xFFEF4444),  // red

  bassColor:        Color(0xFFFF6B35),  // orange
  otherColor:       Color(0xFF48BFE3),  // cyan

  sargamShuddhColor: Color(0xFFE0E0E0),
  sargamShuddhBg:    Color(0x22FFFFFF),
  sargamKomalColor:  Color(0xFF90CAF9),
  sargamTivraColor:  Color(0xFFEF9A9A),

  trimHandleColor:  Color(0xFFFFFFFF),
);
