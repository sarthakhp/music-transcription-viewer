import 'package:flutter/material.dart';
import '../models/view_state.dart';
import 'graph_constants.dart';
import 'graph_renderers/playhead_renderer.dart';
import 'pitch_graph.dart'; // for ActiveNotesHolder

/// Painter for just the playhead (dynamic layer that repaints frequently).
///
/// Reads view parameters from [ViewState] directly so pan/zoom repaints
/// happen via the repaint listenable without widget rebuilds.
class PlayheadPainter extends CustomPainter {
  final ViewState viewState;
  final double currentTime;
  final Color playheadColor;
  final Color onSurfaceColor;
  final Color hoverRowBgColor;
  final Color hoverLabelColor;
  final Color hoverLabelBgColor;
  final Color tooltipBgColor;
  final Brightness brightness;
  final double? hoverTime;
  final double? hoverY;
  final bool sargamEnabled;
  final int scaleRoot;
  final ActiveNotesHolder? activeNotesHolder;

  PlayheadPainter({
    required this.viewState,
    required this.currentTime,
    required this.playheadColor,
    required this.onSurfaceColor,
    required this.hoverRowBgColor,
    required this.hoverLabelColor,
    required this.hoverLabelBgColor,
    required this.tooltipBgColor,
    required this.brightness,
    this.hoverTime,
    this.hoverY,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
    this.activeNotesHolder,
  }) : super(repaint: viewState);

  @override
  void paint(Canvas canvas, Size size) {
    final graphRect = Rect.fromLTRB(
      GraphConstants.leftPadding,
      GraphConstants.topPadding,
      size.width - GraphConstants.rightPadding,
      size.height - GraphConstants.bottomPadding,
    );

    final playheadRenderer = PlayheadRenderer(
      currentTime: currentTime,
      viewStartTime: viewState.viewStartTime,
      viewEndTime: viewState.viewEndTime,
      playheadColor: playheadColor,
      onSurfaceColor: onSurfaceColor,
      hoverRowBgColor: hoverRowBgColor,
      hoverLabelColor: hoverLabelColor,
      hoverLabelBgColor: hoverLabelBgColor,
      tooltipBgColor: tooltipBgColor,
      brightness: brightness,
      hoverTime: hoverTime,
      hoverY: hoverY,
      minMidi: viewState.effectiveMinMidi,
      maxMidi: viewState.effectiveMaxMidi,
      sargamEnabled: sargamEnabled,
      scaleRoot: scaleRoot,
      activeNotePitches: activeNotesHolder?.notes ?? {},
    );

    playheadRenderer.drawActiveNoteLabels(canvas, graphRect);
    playheadRenderer.drawNoteRowHighlight(canvas, graphRect);
    playheadRenderer.drawHoverIndicator(canvas, graphRect);
    playheadRenderer.drawPlayhead(canvas, graphRect);
  }

  @override
  bool shouldRepaint(covariant PlayheadPainter oldDelegate) {
    // Always repaint when currentTime changes (which happens every frame during playback)
    // The activeNotesHolder is mutated in place, so we don't check it here
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.hoverTime != hoverTime ||
        oldDelegate.hoverY != hoverY;
  }
}
