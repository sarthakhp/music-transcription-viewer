import 'package:flutter/material.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import '../models/instrument_data.dart';
import 'graph_constants.dart';
import 'graph_renderers/grid_renderer.dart';
import 'graph_renderers/axis_renderer.dart';
import 'graph_renderers/pitch_renderer.dart';
import 'graph_renderers/chord_renderer.dart';
import 'graph_renderers/instrument_renderer.dart';

/// Custom painter for the pitch visualization (static layer)
/// This painter only draws content that doesn't change frequently:
/// - Grid and background
/// - Axes
/// - Instrument note bars (bass, other)
/// - Pitch points (vocals)
/// - Chord blocks
/// The playhead is drawn separately in PlayheadPainter for better performance
class PitchGraphPainter extends CustomPainter {
  final ProcessedFramesData data;
  final ChordData? chordData;
  final InstrumentData? instrumentData;
  final double viewStartTime;
  final double viewEndTime;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color gridColor;
  final Color unvoicedColor;
  final Color chordColor;
  final Brightness brightness;
  final double referenceFrequency;
  final double minMidi;
  final double maxMidi;
  final bool showVocals;
  final bool showBass;
  final bool showOther;
  final double vocalsMinConfidence;
  final double bassMinConfidence;
  final double otherMinConfidence;
  final int transposeAmount;
  final bool sargamEnabled;
  final int scaleRoot;

  PitchGraphPainter({
    required this.data,
    this.chordData,
    this.instrumentData,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.gridColor,
    required this.unvoicedColor,
    required this.chordColor,
    required this.brightness,
    required this.referenceFrequency,
    required this.minMidi,
    required this.maxMidi,
    this.showVocals = true,
    this.showBass = true,
    this.showOther = true,
    this.vocalsMinConfidence = 0.0,
    this.bassMinConfidence = 0.0,
    this.otherMinConfidence = 0.0,
    this.transposeAmount = 0,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final graphRect = Rect.fromLTRB(
      GraphConstants.leftPadding,
      GraphConstants.topPadding,
      size.width - GraphConstants.rightPadding,
      size.height - GraphConstants.bottomPadding,
    );

    final gridRenderer = GridRenderer(
      data: data,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      gridColor: gridColor,
      brightness: brightness,
      referenceFrequency: referenceFrequency,
      minMidi: minMidi,
      maxMidi: maxMidi,
      sargamEnabled: sargamEnabled,
      scaleRoot: scaleRoot,
    );

    final axisRenderer = AxisRenderer(
      data: data,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      textColor: onSurfaceColor,
      referenceFrequency: referenceFrequency,
      minMidi: minMidi,
      maxMidi: maxMidi,
      sargamEnabled: sargamEnabled,
      scaleRoot: scaleRoot,
    );

    final pitchRenderer = PitchRenderer(
      data: data,
      showUnvoiced: false,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      primaryColor: primaryColor,
      unvoicedColor: unvoicedColor,
      referenceFrequency: referenceFrequency,
      minMidi: minMidi,
      maxMidi: maxMidi,
      minConfidence: vocalsMinConfidence,
      transposeAmount: transposeAmount,
    );

    final chordRenderer = ChordRenderer(
      chordData: chordData,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      chordColor: chordColor,
      textColor: onSurfaceColor,
      brightness: brightness,
      transposeAmount: transposeAmount,
    );

    gridRenderer.drawBackground(canvas, graphRect);
    gridRenderer.drawGrid(canvas, graphRect);
    axisRenderer.drawAxes(canvas, size, graphRect);
    chordRenderer.drawChords(canvas, graphRect);

    // Instrument bars sit below vocal pitch dots so vocals remain readable
    if (instrumentData != null) {
      InstrumentRenderer(
        instrumentData: instrumentData!,
        viewStartTime: viewStartTime,
        viewEndTime: viewEndTime,
        minMidi: minMidi,
        maxMidi: maxMidi,
        showBass: showBass,
        showOther: showOther,
        bassMinConfidence: bassMinConfidence,
        otherMinConfidence: otherMinConfidence,
        transposeAmount: transposeAmount,
      ).drawNotes(canvas, graphRect);
    }

    if (showVocals) {
      pitchRenderer.drawPitchPoints(canvas, graphRect);
    }
  }

  @override
  bool shouldRepaint(covariant PitchGraphPainter oldDelegate) {
    return oldDelegate.viewStartTime != viewStartTime ||
        oldDelegate.viewEndTime != viewEndTime ||
        oldDelegate.chordData != chordData ||
        oldDelegate.instrumentData != instrumentData ||
        oldDelegate.referenceFrequency != referenceFrequency ||
        oldDelegate.data != data ||
        oldDelegate.minMidi != minMidi ||
        oldDelegate.maxMidi != maxMidi ||
        oldDelegate.showVocals != showVocals ||
        oldDelegate.showBass != showBass ||
        oldDelegate.showOther != showOther ||
        oldDelegate.vocalsMinConfidence != vocalsMinConfidence ||
        oldDelegate.bassMinConfidence != bassMinConfidence ||
        oldDelegate.otherMinConfidence != otherMinConfidence ||
        oldDelegate.transposeAmount != transposeAmount ||
        oldDelegate.sargamEnabled != sargamEnabled ||
        oldDelegate.scaleRoot != scaleRoot;
  }
}
