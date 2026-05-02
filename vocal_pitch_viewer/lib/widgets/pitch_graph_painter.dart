import 'package:flutter/material.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import '../models/instrument_data.dart';
import '../models/view_state.dart';
import 'graph_constants.dart';
import 'graph_renderers/grid_renderer.dart';
import 'graph_renderers/axis_renderer.dart';
import 'graph_renderers/pitch_renderer.dart';
import 'graph_renderers/chord_renderer.dart';
import 'graph_renderers/instrument_renderer.dart';

/// Custom painter for the pitch visualization (static layer).
///
/// Reads view parameters (viewStartTime, viewEndTime, minMidi, maxMidi)
/// directly from [ViewState] so that pan/zoom triggers a repaint via the
/// `repaint` listenable — no widget rebuild needed.
class PitchGraphPainter extends CustomPainter {
  static int _paintCount = 0;
  final ViewState viewState;
  final ProcessedFramesData data;
  final ChordData? chordData;
  final InstrumentData? instrumentData;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color gridColor;
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

  PitchGraphPainter({
    required this.viewState,
    required this.data,
    this.chordData,
    this.instrumentData,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.gridColor,
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

    final sw = Stopwatch()..start();

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
      sargamEnabled: sargamEnabled,
      scaleRoot: scaleRoot,
      vocalDetail: vocalDetail,
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
    final gridMs = sw.elapsedMicroseconds / 1000.0;

    sw.reset();
    axisRenderer.drawAxes(canvas, size, graphRect);
    final axisMs = sw.elapsedMicroseconds / 1000.0;

    sw.reset();
    chordRenderer.drawChords(canvas, graphRect);
    final chordMs = sw.elapsedMicroseconds / 1000.0;

    double instrMs = 0;
    if (instrumentData != null) {
      sw.reset();
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
        sargamEnabled: sargamEnabled,
        scaleRoot: scaleRoot,
      ).drawNotes(canvas, graphRect);
      instrMs = sw.elapsedMicroseconds / 1000.0;
    }

    double pitchMs = 0;
    if (showVocals) {
      sw.reset();
      pitchRenderer.drawPitchPoints(canvas, graphRect);
      pitchMs = sw.elapsedMicroseconds / 1000.0;
    }

    final totalMs = gridMs + axisMs + chordMs + instrMs + pitchMs;
    _paintCount++;
    if (_paintCount % 30 == 0) {
      debugPrint('[Paint] total:${totalMs.toStringAsFixed(1)}ms  '
          'grid:${gridMs.toStringAsFixed(1)} axis:${axisMs.toStringAsFixed(1)} '
          'chord:${chordMs.toStringAsFixed(1)} instr:${instrMs.toStringAsFixed(1)} '
          'pitch:${pitchMs.toStringAsFixed(1)}');
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
        oldDelegate.vocalDetail != vocalDetail;
  }
}
