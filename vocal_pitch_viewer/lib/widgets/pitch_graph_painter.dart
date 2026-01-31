import 'package:flutter/material.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import 'graph_constants.dart';
import 'graph_renderers/grid_renderer.dart';
import 'graph_renderers/axis_renderer.dart';
import 'graph_renderers/pitch_renderer.dart';
import 'graph_renderers/playhead_renderer.dart';
import 'graph_renderers/chord_renderer.dart';

/// Custom painter for the pitch visualization
class PitchGraphPainter extends CustomPainter {
  final ProcessedFramesData data;
  final ChordData? chordData;
  final double currentTime;
  final double viewStartTime;
  final double viewEndTime;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color gridColor;
  final Color playheadColor;
  final Color unvoicedColor;
  final Color chordColor;
  final Brightness brightness;
  final double referenceFrequency;
  final double? hoverTime;

  PitchGraphPainter({
    required this.data,
    this.chordData,
    required this.currentTime,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.gridColor,
    required this.playheadColor,
    required this.unvoicedColor,
    required this.chordColor,
    required this.brightness,
    required this.referenceFrequency,
    this.hoverTime,
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

    final playheadRenderer = PlayheadRenderer(
      currentTime: currentTime,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      playheadColor: playheadColor,
      onSurfaceColor: onSurfaceColor,
      brightness: brightness,
      hoverTime: hoverTime,
    );

    final chordRenderer = ChordRenderer(
      chordData: chordData,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      chordColor: chordColor,
      textColor: onSurfaceColor,
      brightness: brightness,
    );

    // Draw in order
    gridRenderer.drawBackground(canvas, graphRect);
    gridRenderer.drawGrid(canvas, graphRect);
    axisRenderer.drawAxes(canvas, size, graphRect);
    chordRenderer.drawChords(canvas, graphRect); // Draw chords before pitch points
    pitchRenderer.drawPitchPoints(canvas, graphRect);
    playheadRenderer.drawHoverIndicator(canvas, graphRect);
    playheadRenderer.drawPlayhead(canvas, graphRect);
  }

  @override
  bool shouldRepaint(covariant PitchGraphPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.viewStartTime != viewStartTime ||
        oldDelegate.viewEndTime != viewEndTime ||
        oldDelegate.chordData != chordData ||
        oldDelegate.referenceFrequency != referenceFrequency ||
        oldDelegate.hoverTime != hoverTime;
  }
}

