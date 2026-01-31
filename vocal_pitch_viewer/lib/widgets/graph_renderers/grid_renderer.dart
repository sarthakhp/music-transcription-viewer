import 'package:flutter/material.dart';
import '../../models/pitch_data.dart';
import '../../utils/music_utils.dart';
import '../graph_constants.dart';

/// Renders grid lines and background for the pitch graph
class GridRenderer {
  final ProcessedFramesData data;
  final double viewStartTime;
  final double viewEndTime;
  final Color gridColor;
  final Brightness brightness;
  final double referenceFrequency;

  GridRenderer({
    required this.data,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.gridColor,
    required this.brightness,
    required this.referenceFrequency,
  });

  void drawBackground(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = brightness == Brightness.dark
          ? const Color(0xFF12121A)
          : const Color(0xFFF8F9FA);
    canvas.drawRect(rect, paint);
  }

  void drawGrid(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = GraphConstants.gridLineWidth;

    // Vertical grid lines (time)
    final timeRange = viewEndTime - viewStartTime;
    final timeStep = GraphConstants.calculateTimeStep(timeRange);

    for (double t = (viewStartTime / timeStep).ceil() * timeStep;
        t <= viewEndTime;
        t += timeStep) {
      final x = _timeToX(t, rect);
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }

    // Horizontal grid lines (piano/MIDI notes)
    _drawPianoGrid(canvas, rect, paint);
  }

  void _drawPianoGrid(Canvas canvas, Rect rect, Paint paint) {
    final range = data.frequencyRange;
    final minMidi = frequencyToMidi(range.$1, referenceFrequency: referenceFrequency).floor() - 2;
    final maxMidi = frequencyToMidi(range.$2, referenceFrequency: referenceFrequency).ceil() + 2;

    // First, draw alternating light/dark bands for each note
    for (int midi = minMidi; midi <= maxMidi; midi++) {
      final topY = _midiToY(midi + 0.5, rect, minMidi.toDouble(), maxMidi.toDouble());
      final bottomY = _midiToY(midi - 0.5, rect, minMidi.toDouble(), maxMidi.toDouble());

      // Alternate bands: even midi = light, odd midi = dark
      if (midi % 2 == 1) {
        final bandPaint = Paint()
          ..color = paint.color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTRB(rect.left, topY, rect.right, bottomY),
          bandPaint,
        );
      }
    }

    // Then draw grid lines at note BOUNDARIES (between notes, at midi + 0.5)
    for (int midi = minMidi; midi <= maxMidi; midi++) {
      final boundaryMidi = midi + 0.5;
      final y = _midiToY(boundaryMidi, rect, minMidi.toDouble(), maxMidi.toDouble());

      // Make lines between B and C (octave boundaries) more prominent
      if (midi % 12 == 11) {
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

