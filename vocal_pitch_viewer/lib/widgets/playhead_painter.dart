import 'package:flutter/material.dart';
import '../models/view_state.dart';
import 'graph_constants.dart';
import 'graph_renderers/playhead_renderer.dart';

/// Painter for just the playhead (dynamic layer that repaints frequently).
///
/// Reads view parameters from [ViewState] directly so pan/zoom repaints
/// happen via the repaint listenable without widget rebuilds.
class PlayheadPainter extends CustomPainter {
  final ViewState viewState;
  final double currentTime;
  final Color playheadColor;
  final Color onSurfaceColor;
  final Brightness brightness;
  final double? hoverTime;
  final double? hoverY;
  final bool sargamEnabled;
  final int scaleRoot;

  PlayheadPainter({
    required this.viewState,
    required this.currentTime,
    required this.playheadColor,
    required this.onSurfaceColor,
    required this.brightness,
    this.hoverTime,
    this.hoverY,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
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
      brightness: brightness,
      hoverTime: hoverTime,
      hoverY: hoverY,
      minMidi: viewState.effectiveMinMidi,
      maxMidi: viewState.effectiveMaxMidi,
      sargamEnabled: sargamEnabled,
      scaleRoot: scaleRoot,
    );

    playheadRenderer.drawNoteRowHighlight(canvas, graphRect);
    playheadRenderer.drawHoverIndicator(canvas, graphRect);
    playheadRenderer.drawPlayhead(canvas, graphRect);
  }

  @override
  bool shouldRepaint(covariant PlayheadPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.hoverTime != hoverTime ||
        oldDelegate.hoverY != hoverY;
  }
}
