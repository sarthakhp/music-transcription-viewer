import 'package:flutter/foundation.dart';

/// Shortest section a trim may keep, in seconds.
const double minTrimSeconds = 0.5;

/// The clip being prepared for upload, as the review screen sees it: its name,
/// length, waveform outline, trim range and playback. The phone (a file on
/// disk) and the website (bytes in the browser) each implement this, so one
/// review screen serves both. Listeners are notified on any change, including
/// the playhead moving.
abstract interface class ClipDraft implements Listenable {
  String? get name;

  /// Length in seconds; 0 while the clip is still being read.
  double get duration;
  double get trimStart;
  double get trimEnd;

  /// Loudness outline, 0..1 per bucket, or null when none could be made.
  List<double>? get peaks;
  bool get isTrimmed;

  double get position;
  bool get playing;

  void setTrim(double start, double end);
  void resetTrim();
  Future<void> toggle();
  Future<void> seek(double seconds);
}
