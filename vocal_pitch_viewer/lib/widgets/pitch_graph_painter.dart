import 'package:flutter/material.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import '../models/instrument_data.dart';
import '../models/view_state.dart';
import '../theme/app_palette.dart';
import 'graph_constants.dart';
import 'graph_renderers/grid_renderer.dart';
import 'graph_renderers/axis_renderer.dart';
import 'graph_renderers/pitch_renderer.dart';
import 'graph_renderers/chord_renderer.dart';
import 'graph_renderers/instrument_renderer.dart';
import 'pitch_graph.dart'; // for ActiveNotesHolder

/// Custom painter for the pitch visualization (static layer).
///
/// Reads view parameters (viewStartTime, viewEndTime, minMidi, maxMidi)
/// directly from [ViewState] so that pan/zoom triggers a repaint via the
/// `repaint` listenable — no widget rebuild needed.
class PitchGraphPainter extends CustomPainter {
  final ViewState viewState;
  final ProcessedFramesData data;
  final ChordData? chordData;
  final InstrumentData? instrumentData;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color gridColor;
  final Color graphBgColor;
  final Color tonicTintColor;
  final Color unvoicedColor;
  final Color chordColor;
  final Brightness brightness;
  final double referenceFrequency;
  final bool showVocals;
  final bool showBass;
  final bool showOther;
  final double vocalsMinConfidence;
  final double bassMinConfidence;
  final double otherMinConfidence;
  final int transposeAmount;
  final bool sargamEnabled;
  final int scaleRoot;
  final int vocalDetail;
  final double currentTime;
  final ActiveNotesHolder? activeNotesHolder;

  PitchGraphPainter({
    required this.viewState,
    required this.data,
    this.chordData,
    this.instrumentData,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.gridColor,
    required this.graphBgColor,
    required this.tonicTintColor,
    required this.unvoicedColor,
    required this.chordColor,
    required this.brightness,
    required this.referenceFrequency,
    this.showVocals = true,
    this.showBass = true,
    this.showOther = true,
    this.vocalsMinConfidence = 0.0,
    this.bassMinConfidence = 0.0,
    this.otherMinConfidence = 0.0,
    this.transposeAmount = 0,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
    this.vocalDetail = 10,
    required this.currentTime,
    this.activeNotesHolder,
  }) : super(repaint: viewState);

  @override
  void paint(Canvas canvas, Size size) {
    // Read view parameters from ViewState (avoids widget rebuild on pan/zoom)
    final viewStartTime = viewState.viewStartTime;
    final viewEndTime = viewState.viewEndTime;
    final minMidi = viewState.effectiveMinMidi;
    final maxMidi = viewState.effectiveMaxMidi;

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
      graphBgColor: graphBgColor,
      tonicTintColor: tonicTintColor,
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
      primaryHighlightColor: appPalette.vocalHighlightColor, // Bright orange for visibility
      unvoicedColor: unvoicedColor,
      referenceFrequency: referenceFrequency,
      minMidi: minMidi,
      maxMidi: maxMidi,
      minConfidence: vocalsMinConfidence,
      transposeAmount: transposeAmount,
      sargamEnabled: sargamEnabled,
      scaleRoot: scaleRoot,
      vocalDetail: vocalDetail,
      currentTime: currentTime,
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

    if (instrumentData != null) {
      final renderer = InstrumentRenderer(
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
        sargamEnabled: sargamEnabled,
        scaleRoot: scaleRoot,
        currentTime: currentTime,
      );

      // Draw instrument bars
      renderer.drawNotes(canvas, graphRect);

      // Find active notes at playhead and update shared holder
      // (works even if playhead is off-screen)
      if (activeNotesHolder != null) {
        activeNotesHolder!.notes = renderer.getActiveNotesAtTime(currentTime);
      }
    }

    if (showVocals) {
      pitchRenderer.drawPitchPoints(canvas, graphRect);
    }
  }

  @override
  bool shouldRepaint(covariant PitchGraphPainter oldDelegate) {
    // ViewState changes are handled by the repaint listenable — no need to
    // check viewStartTime/viewEndTime/minMidi/maxMidi here.
    return oldDelegate.chordData != chordData ||
        oldDelegate.instrumentData != instrumentData ||
        oldDelegate.referenceFrequency != referenceFrequency ||
        oldDelegate.data != data ||
        oldDelegate.showVocals != showVocals ||
        oldDelegate.showBass != showBass ||
        oldDelegate.showOther != showOther ||
        oldDelegate.vocalsMinConfidence != vocalsMinConfidence ||
        oldDelegate.bassMinConfidence != bassMinConfidence ||
        oldDelegate.otherMinConfidence != otherMinConfidence ||
        oldDelegate.transposeAmount != transposeAmount ||
        oldDelegate.sargamEnabled != sargamEnabled ||
        oldDelegate.scaleRoot != scaleRoot ||
        oldDelegate.vocalDetail != vocalDetail ||
        (oldDelegate.currentTime - currentTime).abs() > 0.001; // Repaint when playhead moves
  }
}
