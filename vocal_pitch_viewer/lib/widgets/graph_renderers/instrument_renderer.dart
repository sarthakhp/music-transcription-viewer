import 'package:flutter/material.dart';
import '../../models/instrument_data.dart';
import '../../theme/app_palette.dart';
import '../../utils/music_utils.dart';

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
  final bool sargamEnabled;
  final int scaleRoot;
  final double currentTime;

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
    this.sargamEnabled = false,
    this.scaleRoot = 0,
    required this.currentTime,
  });

  void drawNotes(Canvas canvas, Rect rect) {
    // Height per MIDI semitone, capped so bars don't get absurdly large/small
    final noteHeight = (rect.height / (maxMidi - minMidi)).clamp(3.0, 14.0);

    if (showBass) {
      final track = instrumentData.bass;
      if (track != null) {
        _drawTrack(
          canvas,
          rect,
          track.notes,
          appPalette.bassColor,
          appPalette.bassHighlightColor,
          noteHeight,
          bassMinConfidence,
          transposeAmount,
        );
      }
    }

    if (showOther) {
      final track = instrumentData.other;
      if (track != null) {
        _drawTrack(
          canvas,
          rect,
          track.notes,
          appPalette.otherColor,
          appPalette.otherHighlightColor,
          noteHeight,
          otherMinConfidence,
          transposeAmount,
        );
      }
    }
  }

  /// Finds active notes at the current playhead time
  /// Linear scan through all notes (data is not sorted by onset)
  Map<int, Color> getActiveNotesAtTime(double time) {
    final Map<int, Color> activeNotes = {};

    if (showBass) {
      final track = instrumentData.bass;
      if (track != null) {
        final bassActive = _findActiveNotesInTrack(
          track.notes,
          time,
          appPalette.bassColor,
          bassMinConfidence,
          transposeAmount,
        );
        activeNotes.addAll(bassActive);
      }
    }

    if (showOther) {
      final track = instrumentData.other;
      if (track != null) {
        final otherActive = _findActiveNotesInTrack(
          track.notes,
          time,
          appPalette.otherColor,
          otherMinConfidence,
          transposeAmount,
        );
        activeNotes.addAll(otherActive);
      }
    }

    return activeNotes;
  }

  /// Linear scan to find active notes (data is unsorted, so binary search not applicable)
  Map<int, Color> _findActiveNotesInTrack(
    List<InstrumentNote> notes,
    double time,
    Color color,
    double minConfidence,
    int transpose,
  ) {
    final Map<int, Color> activeNotes = {};

    if (notes.isEmpty) return activeNotes;

    // Linear scan through all notes
    for (final note in notes) {
      // Skip low confidence notes
      if (note.confidence < minConfidence) continue;

      // Check if playhead intersects this note
      if (time >= note.onset && time <= note.offset) {
        final midiPitch = note.pitch + transpose;

        // Only track notes within visible MIDI range
        if (midiPitch >= minMidi && midiPitch <= maxMidi) {
          activeNotes[midiPitch] = color;
        }
      }
    }

    return activeNotes;
  }

  void _drawTrack(
    Canvas canvas,
    Rect rect,
    List<InstrumentNote> notes,
    Color color,
    Color highlightColor,
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

      // Check if playhead intersects with this note
      final isActive = currentTime >= note.onset && currentTime <= note.offset;

      final opacity = 0.55 + (note.velocity / 127.0) * 0.4;
      final baseColor = isActive ? highlightColor : color;
      paint.color = baseColor.withValues(alpha: opacity);

      // Highlighted notes are 1.5x taller for better visibility
      final drawHeight = isActive ? noteHeight * 1.5 : noteHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x1, y - drawHeight / 2, drawWidth, drawHeight),
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
