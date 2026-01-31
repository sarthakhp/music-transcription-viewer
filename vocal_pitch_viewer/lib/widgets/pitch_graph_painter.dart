import 'package:flutter/material.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import 'graph_constants.dart';
import 'graph_renderers/grid_renderer.dart';
import 'graph_renderers/axis_renderer.dart';
import 'graph_renderers/pitch_renderer.dart';
import 'graph_renderers/chord_renderer.dart';

/// Custom painter for the pitch visualization (static layer)
/// This painter only draws content that doesn't change frequently:
/// - Grid and background
/// - Axes
/// - Pitch points
/// - Chord blocks
/// The playhead is drawn separately in PlayheadPainter for better performance
class PitchGraphPainter extends CustomPainter {
  final ProcessedFramesData data;
  final ChordData? chordData;
  final double viewStartTime;
  final double viewEndTime;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color gridColor;
  final Color unvoicedColor;
  final Color chordColor;
  final Brightness brightness;
  final double referenceFrequency;

  PitchGraphPainter({
    required this.data,
    this.chordData,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.gridColor,
    required this.unvoicedColor,
    required this.chordColor,
    required this.brightness,
    required this.referenceFrequency,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final graphRect = Rect.fromLTRB(
      GraphConstants.leftPadding,
      GraphConstants.topPadding,
      size.width - GraphConstants.rightPadding,
      size.height - GraphConstants.bottomPadding,
    );

    // Create renderers
    final gridRenderer = GridRenderer(
      data: data,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      gridColor: gridColor,
      brightness: brightness,
      referenceFrequency: referenceFrequency,
    );

    final axisRenderer = AxisRenderer(
      data: data,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      textColor: onSurfaceColor,
      referenceFrequency: referenceFrequency,
    );

    final pitchRenderer = PitchRenderer(
      data: data,
      showUnvoiced: false,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      primaryColor: primaryColor,
      unvoicedColor: unvoicedColor,
      referenceFrequency: referenceFrequency,
    );

    final chordRenderer = ChordRenderer(
      chordData: chordData,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      chordColor: chordColor,
      textColor: onSurfaceColor,
      brightness: brightness,
    );

    // Draw static content only (no playhead)
    gridRenderer.drawBackground(canvas, graphRect);
    gridRenderer.drawGrid(canvas, graphRect);
    axisRenderer.drawAxes(canvas, size, graphRect);
    chordRenderer.drawChords(canvas, graphRect); // Draw chords before pitch points
    pitchRenderer.drawPitchPoints(canvas, graphRect);
  }

  @override
  bool shouldRepaint(covariant PitchGraphPainter oldDelegate) {
    // Only repaint when view changes or data changes
    // Do NOT repaint when only currentTime or hoverTime changes
    return oldDelegate.viewStartTime != viewStartTime ||
        oldDelegate.viewEndTime != viewEndTime ||
        oldDelegate.chordData != chordData ||
        oldDelegate.referenceFrequency != referenceFrequency ||
        oldDelegate.data != data;
  }
}

