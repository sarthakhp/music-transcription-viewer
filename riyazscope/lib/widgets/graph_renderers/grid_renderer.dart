import 'package:flutter/material.dart';
import '../../models/pitch_data.dart';
import '../graph_constants.dart';

/// Renders grid lines and background for the pitch graph
class GridRenderer {
  final ProcessedFramesData data;
  final double viewStartTime;
  final double viewEndTime;
  final Color gridColor;
  final Color graphBgColor;
  final Color tonicTintColor;
  final Brightness brightness;
  final double referenceFrequency;
  final double minMidi;
  final double maxMidi;
  final bool sargamEnabled;
  final int scaleRoot;

  GridRenderer({
    required this.data,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.gridColor,
    required this.graphBgColor,
    required this.tonicTintColor,
    required this.brightness,
    required this.referenceFrequency,
    required this.minMidi,
    required this.maxMidi,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
  });

  void drawBackground(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = graphBgColor;
    canvas.drawRect(rect, paint);
  }

  void drawGrid(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = GraphConstants.gridLineWidth;

    // Vertical grid lines (time)
    final timeRange = viewEndTime - viewStartTime;
    final timeStep = GraphConstants.calculateTimeStep(timeRange);

    final firstTick = (viewStartTime / timeStep).ceil();
    final lastTick = (viewEndTime / timeStep).floor();
    for (int i = firstTick; i <= lastTick; i++) {
      final x = _timeToX(i * timeStep, rect);
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }

    // Horizontal grid lines (piano/MIDI notes)
    _drawPianoGrid(canvas, rect, paint);
  }

  void _drawPianoGrid(Canvas canvas, Rect rect, Paint paint) {
    // The tonic note for octave reference tint (C in Western, Sa in Sargam).
    final tonicSemitone = sargamEnabled ? scaleRoot : 0; // 0 = C

    // Draw alternating light/dark bands + tonic tint
    for (int midi = minMidi.floor(); midi <= maxMidi.ceil(); midi++) {
      final topY = _midiToY(midi + 0.5, rect, minMidi, maxMidi);
      final bottomY = _midiToY(midi - 0.5, rect, minMidi, maxMidi);
      final bandRect = Rect.fromLTRB(rect.left, topY, rect.right, bottomY);

      // Alternate bands: even midi = light, odd midi = dark
      if (midi % 2 == 1) {
        final bandPaint = Paint()
          ..color = paint.color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawRect(bandRect, bandPaint);
      }

      // Subtle tonic row tint for octave reference
      if (midi % 12 == tonicSemitone) {
        final tonicPaint = Paint()
          ..color = tonicTintColor.withValues(alpha: 0.06)
          ..style = PaintingStyle.fill;
        canvas.drawRect(bandRect, tonicPaint);
      }
    }

    // Grid lines at note boundaries
    // Octave boundary = between the note below tonic and tonic itself.
    final octaveBoundary = ((tonicSemitone - 1) % 12 + 12) % 12;
    for (int midi = minMidi.floor(); midi <= maxMidi.ceil(); midi++) {
      final boundaryMidi = midi + 0.5;
      final y = _midiToY(boundaryMidi, rect, minMidi, maxMidi);

      if (midi % 12 == octaveBoundary) {
        // Stronger line at octave boundary
        final strongPaint = Paint()
          ..color = paint.color.withValues(alpha: 0.5)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), strongPaint);
      } else {
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
      }
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

