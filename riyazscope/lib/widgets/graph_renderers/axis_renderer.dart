import 'package:flutter/material.dart';
import '../../models/pitch_data.dart';
import '../../utils/music_utils.dart';
import '../graph_constants.dart';

/// Renders axis labels for the pitch graph
class AxisRenderer {
  final ProcessedFramesData data;
  final double viewStartTime;
  final double viewEndTime;
  final Color textColor;
  final double referenceFrequency;
  final double minMidi;
  final double maxMidi;
  final bool sargamEnabled;
  final int scaleRoot;

  AxisRenderer({
    required this.data,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.textColor,
    required this.referenceFrequency,
    required this.minMidi,
    required this.maxMidi,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
  });

  void drawAxes(Canvas canvas, Size size, Rect rect) {
    final textStyle = TextStyle(
      color: textColor.withValues(alpha: 0.7),
      fontSize: 10,
    );

    final timeRange = viewEndTime - viewStartTime;
    final timeStep = GraphConstants.calculateTimeStep(timeRange);

    // Draw time labels — use integer multiplier to avoid floating-point drift
    final firstTick = (viewStartTime / timeStep).ceil();
    final lastTick = (viewEndTime / timeStep).floor();
    for (int i = firstTick; i <= lastTick; i++) {
      final t = i * timeStep;
      final x = _timeToX(t, rect);
      final textSpan = TextSpan(text: formatTime(t), style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, rect.bottom + 8));
    }

    // Draw Y-axis labels (piano notes)
    _drawPianoLabels(canvas, rect, textStyle);
  }

  void _drawPianoLabels(Canvas canvas, Rect rect, TextStyle style) {
    final midiRange = maxMidi - minMidi;
    if (midiRange <= 0) return;

    // Row height in pixels — determines font size and skip interval.
    final rowHeight = rect.height / midiRange;

    // Adaptive font size: scale with row height, clamped to 8–14px.
    final fontSize = rowHeight.clamp(8.0, 14.0);

    // Skip labels when rows are too small to fit text.
    // At minimum font (8px), we need ~12px row height to avoid overlap.
    int skipInterval = 1;
    if (rowHeight < 12) skipInterval = 2;
    if (rowHeight < 7) skipInterval = 3;
    if (rowHeight < 5) skipInterval = 6;

    final tonicSemitone = sargamEnabled ? scaleRoot : 0;

    for (int midi = minMidi.floor(); midi <= maxMidi.ceil(); midi++) {
      final semitone = ((midi - tonicSemitone) % 12 + 12) % 12;
      final isTonic = semitone == 0;
      final isDominant = semitone == 7;

      if (skipInterval > 1 && !isTonic && !isDominant) {
        if (semitone % skipInterval != 0) continue;
      }

      final y = _midiToY(midi.toDouble(), rect, minMidi, maxMidi);

      final String label;
      if (sargamEnabled) {
        label = midiToSargam(midi.toDouble(), scaleRoot: scaleRoot);
      } else {
        label = midiToNoteName(midi.toDouble());
      }

      final TextStyle labelStyle;
      if (sargamEnabled) {
        final sargamStyle = SargamTheme.forType(getSargamNoteType(semitone));
        labelStyle = style.copyWith(
          fontSize: fontSize,
          fontWeight: sargamStyle.fontWeight,
          color: sargamStyle.color,
        );
      } else {
        labelStyle = style.copyWith(
          fontSize: fontSize,
          fontWeight: isTonic ? FontWeight.bold : FontWeight.normal,
        );
      }

      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelX = rect.left - tp.width - 8;
      final labelY = y - tp.height / 2;

      if (sargamEnabled) {
        final bg = SargamTheme.forType(getSargamNoteType(semitone)).backgroundColor;
        if (bg != null) {
          const hPad = 4.0;
          const vPad = 2.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(labelX - hPad, labelY - vPad, tp.width + hPad * 2, tp.height + vPad * 2),
              const Radius.circular(3),
            ),
            Paint()..color = bg,
          );
        }
      }

      tp.paint(canvas, Offset(labelX, labelY));
    }
  }

  double _timeToX(double time, Rect rect) {
    final ratio = (time - viewStartTime) / (viewEndTime - viewStartTime);
    return rect.left + ratio * rect.width;
  }

  double _midiToY(double midi, Rect rect, double minMidi, double maxMidi) {
    final ratio = (midi - minMidi) / (maxMidi - minMidi);
    return rect.bottom - ratio * rect.height;
  }
}

