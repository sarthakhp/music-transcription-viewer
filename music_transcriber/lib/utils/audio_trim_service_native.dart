import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'wav_encoder.dart';

/// Android has no Web Audio decoder, so only duration is available. [decode]
/// returns null, which callers treat as "trimming unavailable".
class AudioTrimService {
  static Future<DecodedAudio?> decode(Uint8List bytes) async => null;

  static Future<double?> getDuration(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/duration_probe');
    final player = AudioPlayer();
    try {
      await file.writeAsBytes(bytes, flush: true);
      final d = await player.setFilePath(file.path);
      return d == null ? null : d.inMilliseconds / 1000.0;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
      if (await file.exists()) await file.delete();
    }
  }

  static Uint8List trimAndEncodeWav(
    DecodedAudio audio,
    double startSeconds,
    double endSeconds,
  ) =>
      encodeTrimmedWav(audio, startSeconds, endSeconds);
}
