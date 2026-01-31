import 'package:flutter/material.dart';
import '../../models/chord_data.dart';

/// Renders chord blocks on the graph
class ChordRenderer {
  final ChordData? chordData;
  final double viewStartTime;
  final double viewEndTime;
  final Color chordColor;
  final Color textColor;
  final Brightness brightness;

  ChordRenderer({
    required this.chordData,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.chordColor,
    required this.textColor,
    required this.brightness,
  });

  void drawChords(Canvas canvas, Rect rect) {
    if (chordData == null) return;

    // Get chords in the visible time range
    final visibleChords = chordData!.getChordsInRange(viewStartTime, viewEndTime);

    for (final chord in visibleChords) {
      _drawChordBlock(canvas, rect, chord);
    }
  }

  void _drawChordBlock(Canvas canvas, Rect rect, Chord chord) {
    // Skip "No Chord" blocks if desired (or render them differently)
    if (chord.isNoChord) {
      return; // Don't render "N" chords
    }

    final startX = _timeToX(chord.startTime, rect);
    final endX = _timeToX(chord.endTime, rect);
    final width = endX - startX;

    // Don't render if too small
    if (width < 1) return;

    // Calculate opacity based on confidence
    final opacity = (chord.confidence * 0.5 + 0.3).clamp(0.3, 0.8);

    // Draw chord block background
    final blockPaint = Paint()
      ..color = chordColor.withValues(alpha: opacity * 0.3)
      ..style = PaintingStyle.fill;

    final blockRect = Rect.fromLTRB(
      startX,
      rect.top,
      endX,
      rect.top + 30, // Fixed height at top of graph
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(blockRect, const Radius.circular(4)),
      blockPaint,
    );

    // Draw border
    final borderPaint = Paint()
      ..color = chordColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(blockRect, const Radius.circular(4)),
      borderPaint,
    );

    // Draw chord label if there's enough space
    if (width > 20) {
      final textStyle = TextStyle(
        color: textColor,
        fontSize: width > 40 ? 11 : 9,
        fontWeight: FontWeight.w600,
      );

      final tp = TextPainter(
        text: TextSpan(text: chord.displayLabel, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: width - 4);

      // Center the text in the block
      final textX = startX + (width - tp.width) / 2;
      final textY = rect.top + (30 - tp.height) / 2;

      tp.paint(canvas, Offset(textX, textY));
    }
  }

  double _timeToX(double time, Rect rect) {
    final viewDuration = viewEndTime - viewStartTime;
    if (viewDuration == 0) return rect.left;

    final ratio = (time - viewStartTime) / viewDuration;
    return rect.left + ratio * rect.width;
  }
}

