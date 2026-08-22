import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class DecodedAudio {
  final List<Float32List> channels;
  final int sampleRate;
  final double duration;

  DecodedAudio({
    required this.channels,
    required this.sampleRate,
    required this.duration,
  });
}

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

  /// Slice [audio] from [startSeconds] to [endSeconds] and encode as 16-bit PCM WAV.
  static Uint8List trimAndEncodeWav(
    DecodedAudio audio,
    double startSeconds,
    double endSeconds,
  ) {
    final totalSamples = audio.channels[0].length;
    final startSample =
        (startSeconds * audio.sampleRate).round().clamp(0, totalSamples);
    final endSample =
        (endSeconds * audio.sampleRate).round().clamp(startSample, totalSamples);
    final numSamples = endSample - startSample;
    final numChannels = audio.channels.length;

    final dataBytes = numSamples * numChannels * 2; // 16-bit = 2 bytes/sample
    final buf = ByteData(44 + dataBytes);

    // ---- RIFF header ----
    _setFourCC(buf, 0, 'RIFF');
    buf.setUint32(4, 36 + dataBytes, Endian.little);
    _setFourCC(buf, 8, 'WAVE');

    // ---- fmt  chunk ----
    _setFourCC(buf, 12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);             // chunk size
    buf.setUint16(20, 1, Endian.little);              // PCM
    buf.setUint16(22, numChannels, Endian.little);
    buf.setUint32(24, audio.sampleRate, Endian.little);
    buf.setUint32(28, audio.sampleRate * numChannels * 2, Endian.little); // byte rate
    buf.setUint16(32, numChannels * 2, Endian.little); // block align
    buf.setUint16(34, 16, Endian.little);              // bits per sample

    // ---- data chunk ----
    _setFourCC(buf, 36, 'data');
    buf.setUint32(40, dataBytes, Endian.little);

    // ---- interleaved PCM samples ----
    var offset = 44;
    for (var i = 0; i < numSamples; i++) {
      for (var c = 0; c < numChannels; c++) {
        final sample = audio.channels[c][startSample + i].clamp(-1.0, 1.0);
        buf.setInt16(offset, (sample * 32767).round(), Endian.little);
        offset += 2;
      }
    }

    return buf.buffer.asUint8List();
  }

  static void _setFourCC(ByteData buf, int offset, String fourCC) {
    for (var i = 0; i < 4; i++) {
      buf.setUint8(offset + i, fourCC.codeUnitAt(i));
    }
  }
}
