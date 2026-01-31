import 'package:flutter/material.dart';
import '../../utils/music_utils.dart';
import '../graph_constants.dart';

/// Renders playhead and hover indicator on the graph
class PlayheadRenderer {
  final double currentTime;
  final double viewStartTime;
  final double viewEndTime;
  final Color playheadColor;
  final Color onSurfaceColor;
  final Brightness brightness;
  final double? hoverTime;

  PlayheadRenderer({
    required this.currentTime,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.playheadColor,
    required this.onSurfaceColor,
    required this.brightness,
    this.hoverTime,
  });

  void drawPlayhead(Canvas canvas, Rect rect) {
    if (currentTime < viewStartTime || currentTime > viewEndTime) return;

    final x = _timeToX(currentTime, rect);
    final paint = Paint()
      ..color = playheadColor
      ..strokeWidth = GraphConstants.playheadWidth;

    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);

    // Draw time indicator at top
    final textStyle = TextStyle(
      color: playheadColor,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );
    final tp = TextPainter(
      text: TextSpan(text: formatTime(currentTime), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgPaint = Paint()..color = playheadColor.withValues(alpha: 0.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, rect.top - 12),
          width: tp.width + 8,
          height: tp.height + 4,
        ),
        const Radius.circular(4),
      ),
      bgPaint,
    );
    tp.paint(canvas, Offset(x - tp.width / 2, rect.top - 18));
  }

  void drawHoverIndicator(Canvas canvas, Rect rect) {
    if (hoverTime == null) return;
    if (hoverTime! < viewStartTime || hoverTime! > viewEndTime) return;

    final x = _timeToX(hoverTime!, rect);

    // Draw semi-transparent vertical line
    final paint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.3)
      ..strokeWidth = GraphConstants.hoverLineWidth;

    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);

    // Draw time tooltip at bottom
    final textStyle = TextStyle(
      color: onSurfaceColor.withValues(alpha: 0.8),
      fontSize: 10,
    );
    final tp = TextPainter(
      text: TextSpan(text: formatTime(hoverTime!), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    // Background for tooltip
    final bgPaint = Paint()
      ..color = brightness == Brightness.dark
          ? const Color(0xFF2A2A3A)
          : const Color(0xFFE8E8EC);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, rect.bottom + 20),
          width: tp.width + 12,
          height: tp.height + 6,
        ),
        const Radius.circular(4),
      ),
      bgPaint,
    );
    tp.paint(canvas, Offset(x - tp.width / 2, rect.bottom + 14));
  }

  double _timeToX(double time, Rect rect) {
    final ratio = (time - viewStartTime) / (viewEndTime - viewStartTime);
    return rect.left + ratio * rect.width;
  }
}

