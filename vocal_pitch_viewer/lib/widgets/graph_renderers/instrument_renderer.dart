import 'package:flutter/material.dart';
import '../../models/instrument_data.dart';

const Color _bassColor = Color(0xFFFF6B35);   // orange
const Color _otherColor = Color(0xFF48BFE3);  // cyan

/// Renders instrument note bars (bass + other stems) on the pitch graph canvas
class InstrumentRenderer {
  final InstrumentData instrumentData;
  final double viewStartTime;
  final double viewEndTime;
  final double minMidi;
  final double maxMidi;
  final bool showBass;
  final bool showOther;
  final double bassMinConfidence;
  final double otherMinConfidence;
  final int transposeAmount;

  static const double _minNoteWidth = 3.0;

  const InstrumentRenderer({
    required this.instrumentData,
    required this.viewStartTime,
    required this.viewEndTime,
    required this.minMidi,
    required this.maxMidi,
    required this.showBass,
    required this.showOther,
    this.bassMinConfidence = 0.0,
    this.otherMinConfidence = 0.0,
    this.transposeAmount = 0,
  });

  void drawNotes(Canvas canvas, Rect rect) {
    // Height per MIDI semitone, capped so bars don't get absurdly large/small
    final noteHeight = (rect.height / (maxMidi - minMidi)).clamp(3.0, 14.0);

    if (showBass) {
      final track = instrumentData.bass;
      if (track != null) {
        _drawTrack(canvas, rect, track.notes, _bassColor, noteHeight, bassMinConfidence, transposeAmount);
      }
    }

    if (showOther) {
      final track = instrumentData.other;
      if (track != null) {
        _drawTrack(canvas, rect, track.notes, _otherColor, noteHeight, otherMinConfidence, transposeAmount);
      }
    }
  }

  void _drawTrack(
    Canvas canvas,
    Rect rect,
    List<InstrumentNote> notes,
    Color color,
    double noteHeight,
    double minConfidence,
    int transpose,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    const radius = Radius.circular(2.0);

    for (final note in notes) {
      if (note.confidence < minConfidence) continue;
      if (note.offset < viewStartTime || note.onset > viewEndTime) continue;

      final midiPitch = note.pitch.toDouble() + transpose;
      if (midiPitch < minMidi || midiPitch > maxMidi) continue;

      final x1 = _timeToX(note.onset.clamp(viewStartTime, viewEndTime), rect);
      final x2 = _timeToX(note.offset.clamp(viewStartTime, viewEndTime), rect);
      final y = _midiToY(midiPitch, rect);

      final drawWidth = (x2 - x1).clamp(_minNoteWidth, double.infinity);

      // Map velocity to opacity in range 55%-95%
      final opacity = 0.55 + (note.velocity / 127.0) * 0.4;
      paint.color = color.withValues(alpha: opacity);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x1, y - noteHeight / 2, drawWidth, noteHeight),
          radius,
        ),
        paint,
      );
    }
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
