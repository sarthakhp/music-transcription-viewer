import 'dart:typed_data';
import '../utils/audio_export_interop.dart';

/// Client-side, backend-free MP3 export for Practice Mode: applies the same
/// pitch/speed shift as live playback and renders offline instead of in
/// real time.
class AudioExportService {
  static Future<Uint8List> exportMp3(
    Uint8List sourceBytes, {
    required int semitones,
    required double speed,
    void Function(double progress)? onProgress,
  }) {
    if (sourceBytes.isEmpty) {
      throw ArgumentError('sourceBytes must not be empty');
    }
    return jsExportMp3(
      sourceBytes,
      semitones: semitones,
      speed: speed,
      onProgress: onProgress,
    );
  }
}
