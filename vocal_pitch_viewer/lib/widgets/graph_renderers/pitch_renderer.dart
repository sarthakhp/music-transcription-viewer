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
  final Color primaryHighlightColor;
  final Color unvoicedColor;
  final double referenceFrequency;
  final double minMidi;
  final double maxMidi;
  final double minConfidence;
  final int transposeAmount;
  final bool sargamEnabled;
  final int scaleRoot;
  final int vocalDetail;
  final double currentTime;

  PitchRenderer({
    required this.data,
    required this.showUnvoiced,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.primaryColor,
    required this.primaryHighlightColor,
    required this.unvoicedColor,
    required this.referenceFrequency,
    required this.minMidi,
    required this.maxMidi,
    this.minConfidence = 0.0,
    this.transposeAmount = 0,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
    this.vocalDetail = 10,
    this.currentTime = 0.0,
  });

  void drawPitchPoints(Canvas canvas, Rect rect) {

    // Find the visible frame range using binary search for better performance
    final startIndex = _findStartIndex();
    final endIndex = _findEndIndex();

    if (startIndex == -1 || endIndex == -1 || startIndex > endIndex) {
      return; // No visible frames
    }

    // Key: alpha only — no color variation by note type
    final Map<double, List<Offset>> normalBuckets = {};
    final Map<double, List<Offset>> highlightBuckets = {};
    final List<Offset> unvoicedPoints = [];

    for (int i = startIndex; i <= endIndex; i++) {
      final frame = data.getDisplayFrames(framesPerSecond: vocalDetail)[i];

      if (!frame.isVoiced && !showUnvoiced) continue;
      if (frame.confidence < minConfidence) continue;

      final x = _timeToX(frame.time, rect);

      if (frame.frequency <= 0) continue;
      final midiPitch = frequencyToMidi(frame.frequency, referenceFrequency: referenceFrequency) + transposeAmount;
      final y = _midiToY(midiPitch, rect, minMidi, maxMidi);

      if (y < rect.top || y > rect.bottom) continue;

      final offset = Offset(x, y);

      if (frame.isVoiced) {
        final isActive = (frame.time - currentTime).abs() < 0.2; // Within 200ms of playhead
        final alpha = GraphConstants.voicedMinAlpha +
            frame.confidence * (GraphConstants.voicedMaxAlpha - GraphConstants.voicedMinAlpha);
        final targetBuckets = isActive ? highlightBuckets : normalBuckets;
        targetBuckets.putIfAbsent(alpha, () => []).add(offset);
      } else {
        unvoicedPoints.add(offset);
      }
    }

    if (unvoicedPoints.isNotEmpty) {
      final paint = Paint()
        ..color = unvoicedColor
        ..strokeWidth = GraphConstants.unvoicedPointRadius * 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawPoints(ui.PointMode.points, unvoicedPoints, paint);
    }

    // Two-pass drawing: fill circles, then border rings (batched via drawPoints)
    final fillDiameter = GraphConstants.voicedPointRadius * 2;
    final borderDiameter = fillDiameter + GraphConstants.voicedPointBorderWidth;

    // Highlighted dots are 1.5x bigger for better visibility
    final highlightFillDiameter = fillDiameter * 1.5;
    final highlightBorderDiameter = highlightFillDiameter + GraphConstants.voicedPointBorderWidth;

    // Draw normal points
    normalBuckets.forEach((alpha, points) {
      if (points.isEmpty) return;

      // Pass 1: filled circle
      final fillPaint = Paint()
        ..color = primaryColor.withValues(alpha: alpha)
        ..strokeWidth = fillDiameter
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.fill;
      canvas.drawPoints(ui.PointMode.points, points, fillPaint);

      // Pass 2: border ring
      final borderPaint = Paint()
        ..color = primaryColor.withValues(alpha: GraphConstants.voicedPointBorderAlpha)
        ..strokeWidth = borderDiameter
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPoints(ui.PointMode.points, points, borderPaint);
    });

    // Draw highlighted points (bigger and orange)
    highlightBuckets.forEach((alpha, points) {
      if (points.isEmpty) return;

      // Pass 1: filled circle (1.5x bigger)
      final fillPaint = Paint()
        ..color = primaryHighlightColor.withValues(alpha: alpha)
        ..strokeWidth = highlightFillDiameter
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.fill;
      canvas.drawPoints(ui.PointMode.points, points, fillPaint);

      // Pass 2: border ring (1.5x bigger)
      final borderPaint = Paint()
        ..color = primaryHighlightColor.withValues(alpha: GraphConstants.voicedPointBorderAlpha)
        ..strokeWidth = highlightBorderDiameter
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPoints(ui.PointMode.points, points, borderPaint);
    });
  }

  /// Binary search to find the first frame that might be visible
  int _findStartIndex() {
    final frames = data.getDisplayFrames(framesPerSecond: vocalDetail);
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
    final frames = data.getDisplayFrames(framesPerSecond: vocalDetail);
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

