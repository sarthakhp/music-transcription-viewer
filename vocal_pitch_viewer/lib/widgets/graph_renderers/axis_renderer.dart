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

  AxisRenderer({
    required this.data,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.textColor,
    required this.referenceFrequency,
  });

  void drawAxes(Canvas canvas, Size size, Rect rect) {
    final textStyle = TextStyle(
      color: textColor.withValues(alpha: 0.7),
      fontSize: 10,
    );

    final timeRange = viewEndTime - viewStartTime;
    final timeStep = GraphConstants.calculateTimeStep(timeRange);

    // Draw time labels
    for (double t = (viewStartTime / timeStep).ceil() * timeStep;
        t <= viewEndTime;
        t += timeStep) {
      final x = _timeToX(t, rect);
      final textSpan = TextSpan(text: formatTime(t), style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, rect.bottom + 8));
    }

    // Draw Y-axis labels (piano notes)
    _drawPianoLabels(canvas, rect, textStyle);
  }

  void _drawPianoLabels(Canvas canvas, Rect rect, TextStyle style) {
    final range = data.frequencyRange;
    final minMidi = frequencyToMidi(range.$1, referenceFrequency: referenceFrequency).floor() - 2;
    final maxMidi = frequencyToMidi(range.$2, referenceFrequency: referenceFrequency).ceil() + 2;

    // Draw label for each note
    for (int midi = minMidi; midi <= maxMidi; midi++) {
      final y = _midiToY(midi.toDouble(), rect, minMidi.toDouble(), maxMidi.toDouble());
      final label = midiToNoteName(midi.toDouble());
      // Make C notes (octave markers) bold
      final labelStyle = midi % 12 == 0
          ? style.copyWith(fontWeight: FontWeight.bold)
          : style;
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left - tp.width - 8, y - tp.height / 2));
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

