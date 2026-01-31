import 'package:flutter/material.dart';
import '../../models/pitch_data.dart';
import '../../utils/music_utils.dart';
import '../graph_constants.dart';

/// Renders pitch points on the graph
class PitchRenderer {
  final ProcessedFramesData data;
  final bool showUnvoiced;
  final double viewStartTime;
  final double viewEndTime;
  final Color primaryColor;
  final Color unvoicedColor;
  final double referenceFrequency;

  PitchRenderer({
    required this.data,
    required this.showUnvoiced,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.primaryColor,
    required this.unvoicedColor,
    required this.referenceFrequency,
  });

  void drawPitchPoints(Canvas canvas, Rect rect) {
    final range = data.frequencyRange;
    final minMidi = frequencyToMidi(range.$1, referenceFrequency: referenceFrequency).floor() - 2;
    final maxMidi = frequencyToMidi(range.$2, referenceFrequency: referenceFrequency).ceil() + 2;

    for (final frame in data.processedFrames) {
      if (frame.time < viewStartTime || frame.time > viewEndTime) continue;
      if (!frame.isVoiced && !showUnvoiced) continue;

      final x = _timeToX(frame.time, rect);

      // Always use MIDI/piano mode
      // Recalculate MIDI pitch from frequency using current reference frequency
      if (frame.frequency <= 0) continue;
      final midiPitch = frequencyToMidi(frame.frequency, referenceFrequency: referenceFrequency);
      final y = _midiToY(midiPitch, rect, minMidi.toDouble(), maxMidi.toDouble());

      if (y < rect.top || y > rect.bottom) continue;

      final paint = Paint()
        ..color = frame.isVoiced
            ? primaryColor.withValues(alpha: frame.confidence.clamp(0.3, 1.0))
            : unvoicedColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        frame.isVoiced ? GraphConstants.voicedPointRadius : GraphConstants.unvoicedPointRadius,
        paint,
      );
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

