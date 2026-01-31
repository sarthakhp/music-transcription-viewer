import 'package:flutter/material.dart';
import 'graph_constants.dart';
import 'graph_renderers/playhead_renderer.dart';

/// Painter for just the playhead (dynamic layer that repaints frequently)
/// This is separated from the main graph to avoid repainting pitch points
class PlayheadPainter extends CustomPainter {
  final double currentTime;
  final double viewStartTime;
  final double viewEndTime;
  final Color playheadColor;
  final Color onSurfaceColor;
  final Brightness brightness;
  final double? hoverTime;

  PlayheadPainter({
    required this.currentTime,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.playheadColor,
    required this.onSurfaceColor,
    required this.brightness,
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

    final playheadRenderer = PlayheadRenderer(
      currentTime: currentTime,
      viewStartTime: viewStartTime,
      viewEndTime: viewEndTime,
      playheadColor: playheadColor,
      onSurfaceColor: onSurfaceColor,
      brightness: brightness,
      hoverTime: hoverTime,
    );

    // Only draw the playhead and hover indicator
    playheadRenderer.drawHoverIndicator(canvas, graphRect);
    playheadRenderer.drawPlayhead(canvas, graphRect);
  }

  @override
  bool shouldRepaint(covariant PlayheadPainter oldDelegate) {
    // Only repaint when currentTime or hoverTime changes
    // This is much more efficient than repainting the entire graph
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.hoverTime != hoverTime;
  }
}

