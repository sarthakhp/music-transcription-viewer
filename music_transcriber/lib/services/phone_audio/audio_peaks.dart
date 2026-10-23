import 'package:flutter/services.dart';
import 'selected_audio.dart';
import 'wav_peaks.dart';

const _channel = MethodChannel('music_transcriber/audio_peaks');

/// Loudness outline of [audio] for the trim view: [buckets] values in 0..1.
///
/// WAV files are read directly; anything else (mp3, m4a, ogg, flac) is decoded
/// by Android's own codecs. Returns null when no outline can be made, in which
/// case the view shows a plain bar and trimming still works.
Future<List<double>?> readAudioPeaks(SelectedAudio audio, {int buckets = 160}) async {
  if (audio.isWav) {
    final wavPeaks = await readWavPeaks(audio.path, buckets: buckets);
    if (wavPeaks != null) return wavPeaks;
  }
  try {
    final peaks = await _channel.invokeListMethod<double>(
      'peaks',
      {'path': audio.path, 'buckets': buckets},
    );
    return peaks == null || peaks.isEmpty ? null : peaks;
  } on MissingPluginException {
    return null; // not Android
  } on PlatformException {
    return null;
  }
}
