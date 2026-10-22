import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'wav_encoder.dart';

class AudioTrimService {
  /// Decode audio bytes to raw PCM using the browser's Web Audio API.
  static Future<DecodedAudio?> decode(Uint8List bytes) async {
    final ctx = web.AudioContext();
    try {
      // decodeAudioData transfers the ArrayBuffer, zeroing the source — copy first.
      final audioBuffer = await ctx.decodeAudioData(Uint8List.fromList(bytes).buffer.toJS).toDart;
      final numChannels = audioBuffer.numberOfChannels;
      final sampleRate = audioBuffer.sampleRate.toInt();
      final length = audioBuffer.length;

      final channels = <Float32List>[];
      for (var i = 0; i < numChannels; i++) {
        // Copy into a Dart-owned list so we don't hold a JS reference after
        // the AudioContext is closed.
        final jsData = audioBuffer.getChannelData(i).toDart;
        channels.add(Float32List.fromList(jsData));
      }

      return DecodedAudio(
        channels: channels,
        sampleRate: sampleRate,
        duration: length / sampleRate,
      );
    } catch (_) {
      return null;
    } finally {
      ctx.close();
    }
  }

  /// Quick duration-only decode (cheaper than full decode when no trim needed).
  static Future<double?> getDuration(Uint8List bytes) async {
    final ctx = web.AudioContext();
    try {
      // decodeAudioData transfers the ArrayBuffer — copy first to keep bytes intact.
      final ab = await ctx.decodeAudioData(Uint8List.fromList(bytes).buffer.toJS).toDart;
      return ab.length / ab.sampleRate;
    } catch (_) {
      return null;
    } finally {
      ctx.close();
    }
  }

  static Uint8List trimAndEncodeWav(DecodedAudio audio, double startSeconds, double endSeconds) =>
      encodeTrimmedWav(audio, startSeconds, endSeconds);
}
