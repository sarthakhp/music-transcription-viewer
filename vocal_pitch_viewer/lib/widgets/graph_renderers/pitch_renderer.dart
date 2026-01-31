import 'dart:ui' as ui;
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

    // Find the visible frame range using binary search for better performance
    final startIndex = _findStartIndex();
    final endIndex = _findEndIndex();

    if (startIndex == -1 || endIndex == -1 || startIndex > endIndex) {
      return; // No visible frames
    }

    // Group points by their rendering properties for batching
    // We'll use a map to group points by their alpha value (confidence)
    final Map<double, List<Offset>> voicedPointsByAlpha = {};
    final List<Offset> unvoicedPoints = [];

    // Iterate only through visible frames
    for (int i = startIndex; i <= endIndex; i++) {
      final frame = data.processedFrames[i];

      if (!frame.isVoiced && !showUnvoiced) continue;

      final x = _timeToX(frame.time, rect);

      // Always use MIDI/piano mode
      // Recalculate MIDI pitch from frequency using current reference frequency
      if (frame.frequency <= 0) continue;
      final midiPitch = frequencyToMidi(frame.frequency, referenceFrequency: referenceFrequency);
      final y = _midiToY(midiPitch, rect, minMidi.toDouble(), maxMidi.toDouble());

      if (y < rect.top || y > rect.bottom) continue;

      final offset = Offset(x, y);

      if (frame.isVoiced) {
        // Group voiced points by alpha (confidence) for batching
        final alpha = frame.confidence.clamp(0.3, 1.0);
        voicedPointsByAlpha.putIfAbsent(alpha, () => []).add(offset);
      } else {
        unvoicedPoints.add(offset);
      }
    }

    // Draw all unvoiced points in one batch
    if (unvoicedPoints.isNotEmpty) {
      final paint = Paint()
        ..color = unvoicedColor
        ..strokeWidth = GraphConstants.unvoicedPointRadius * 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawPoints(ui.PointMode.points, unvoicedPoints, paint);
    }

    // Draw voiced points batched by alpha value
    voicedPointsByAlpha.forEach((alpha, points) {
      if (points.isNotEmpty) {
        final paint = Paint()
          ..color = primaryColor.withValues(alpha: alpha)
          ..strokeWidth = GraphConstants.voicedPointRadius * 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        canvas.drawPoints(ui.PointMode.points, points, paint);
      }
    });
  }

  /// Binary search to find the first frame that might be visible
  int _findStartIndex() {
    final frames = data.processedFrames;
    if (frames.isEmpty) return -1;

    // If the first frame is already past our view, return -1
    if (frames.first.time > viewEndTime) return -1;

    // If the last frame is before our view, return -1
    if (frames.last.time < viewStartTime) return -1;

    // Binary search for the first frame >= viewStartTime
    int left = 0;
    int right = frames.length - 1;
    int result = 0;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      if (frames[mid].time < viewStartTime) {
        left = mid + 1;
      } else {
        result = mid;
        right = mid - 1;
      }
    }

    return result;
  }

  /// Binary search to find the last frame that might be visible
  int _findEndIndex() {
    final frames = data.processedFrames;
    if (frames.isEmpty) return -1;

    // If the first frame is already past our view, return -1
    if (frames.first.time > viewEndTime) return -1;

    // If the last frame is before our view, return -1
    if (frames.last.time < viewStartTime) return -1;

    // Binary search for the last frame <= viewEndTime
    int left = 0;
    int right = frames.length - 1;
    int result = frames.length - 1;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      if (frames[mid].time <= viewEndTime) {
        result = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return result;
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

