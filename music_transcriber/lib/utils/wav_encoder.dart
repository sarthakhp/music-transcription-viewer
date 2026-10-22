import 'dart:typed_data';

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

  /// Slice [audio] from [startSeconds] to [endSeconds] and encode as 16-bit PCM WAV.
  Uint8List encodeTrimmedWav(
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

  void _setFourCC(ByteData buf, int offset, String fourCC) {
    for (var i = 0; i < 4; i++) {
      buf.setUint8(offset + i, fourCC.codeUnitAt(i));
    }
  }
