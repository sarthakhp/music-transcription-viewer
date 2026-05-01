import 'package:flutter/material.dart';
import '../../utils/music_utils.dart';
import '../graph_constants.dart';

/// Renders playhead, hover indicator, and note row highlight on the graph
class PlayheadRenderer {
  final double currentTime;
  final double viewStartTime;
  final double viewEndTime;
  final Color playheadColor;
  final Color onSurfaceColor;
  final Brightness brightness;
  final double? hoverTime;
  final double? hoverY;
  final double minMidi;
  final double maxMidi;
  final bool sargamEnabled;
  final int scaleRoot;

  PlayheadRenderer({
    required this.currentTime,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.playheadColor,
    required this.onSurfaceColor,
    required this.brightness,
    this.hoverTime,
    this.hoverY,
    required this.minMidi,
    required this.maxMidi,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
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
      text: TextSpan(text: formatTimeWithMs(currentTime), style: textStyle),
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
      text: TextSpan(text: formatTimeWithMs(hoverTime!), style: textStyle),
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

  /// Draw a subtle row highlight + floating note label at the cursor.
  void drawNoteRowHighlight(Canvas canvas, Rect rect) {
    if (hoverY == null) return;
    // Only highlight when cursor is within the graph area.
    if (hoverY! < rect.top || hoverY! > rect.bottom) return;

    // Convert cursor Y to MIDI note (snapped to nearest integer).
    final midiRange = maxMidi - minMidi;
    if (midiRange <= 0) return;
    final ratio = (rect.bottom - hoverY!) / rect.height;
    final midi = (minMidi + ratio * midiRange).roundToDouble();

    // Compute the Y band for this note (midi - 0.5 to midi + 0.5).
    final rowTop = _midiToY(midi + 0.5, rect);
    final rowBottom = _midiToY(midi - 0.5, rect);
    final rowCenterY = (rowTop + rowBottom) / 2;

    // Clamp to graph rect.
    final clampedTop = rowTop.clamp(rect.top, rect.bottom);
    final clampedBottom = rowBottom.clamp(rect.top, rect.bottom);
    if (clampedTop >= clampedBottom) return;

    // Subtle row highlight.
    final highlightPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: brightness == Brightness.dark ? 0.07 : 0.06);
    canvas.drawRect(
      Rect.fromLTRB(rect.left, clampedTop, rect.right, clampedBottom),
      highlightPaint,
    );

    // Highlighted Y-axis label (drawn in foreground to "glow" over the static label).
    _drawHighlightedAxisLabel(canvas, rect, midi);

    // Don't draw the floating label if cursor is near the left axis labels.
    if (hoverTime == null) return;
    final cursorX = _timeToX(hoverTime!, rect);
    if (cursorX - rect.left < 60) return;

    // Floating note label near cursor.
    final noteName = sargamEnabled
        ? midiToSargam(midi, scaleRoot: scaleRoot)
        : midiToNoteName(midi);
    final labelStyle = TextStyle(
      color: onSurfaceColor.withValues(alpha: 0.9),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    final tp = TextPainter(
      text: TextSpan(text: noteName, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelW = tp.width + 10;
    final labelH = tp.height + 6;
    // Position: to the right of the cursor, vertically centered on the row.
    final labelX = (cursorX + 14).clamp(rect.left, rect.right - labelW);
    final labelY = (rowCenterY - labelH / 2).clamp(rect.top, rect.bottom - labelH);

    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF2A2A3A)
        : const Color(0xFFE8E8EC);
    final bgPaint = Paint()..color = bgColor;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelX, labelY, labelW, labelH),
      const Radius.circular(4),
    );
    canvas.drawRRect(rrect, bgPaint);
    tp.paint(canvas, Offset(labelX + 5, labelY + 3));
  }

  /// Draw a highlighted label at the Y-axis for the hovered note row.
  void _drawHighlightedAxisLabel(Canvas canvas, Rect rect, double midi) {
    final midiRange = maxMidi - minMidi;
    if (midiRange <= 0) return;

    final noteName = sargamEnabled
        ? midiToSargam(midi, scaleRoot: scaleRoot)
        : midiToNoteName(midi);

    // Match adaptive font size from AxisRenderer.
    final rowHeight = rect.height / midiRange;
    final fontSize = rowHeight.clamp(8.0, 14.0);

    final rowCenterY = _midiToY(midi, rect);

    final labelStyle = TextStyle(
      color: onSurfaceColor,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );
    final tp = TextPainter(
      text: TextSpan(text: noteName, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelX = rect.left - tp.width - 8;
    final labelY = rowCenterY - tp.height / 2;

    // Background pill behind the label.
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelX - 4,
        labelY - 2,
        tp.width + 8,
        tp.height + 4,
      ),
      const Radius.circular(3),
    );
    final pillColor = brightness == Brightness.dark
        ? onSurfaceColor.withValues(alpha: 0.12)
        : onSurfaceColor.withValues(alpha: 0.08);
    canvas.drawRRect(pillRect, Paint()..color = pillColor);

    tp.paint(canvas, Offset(labelX, labelY));
  }

  double _timeToX(double time, Rect rect) {
    final ratio = (time - viewStartTime) / (viewEndTime - viewStartTime);
    return rect.left + ratio * rect.width;
  }

  double _midiToY(double midi, Rect rect) {
    final ratio = (midi - minMidi) / (maxMidi - minMidi);
    return rect.bottom - ratio * rect.height;
  }
}
