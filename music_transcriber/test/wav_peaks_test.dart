import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/services/phone_audio/wav_peaks.dart';

/// A mono 16-bit WAV: [loud] seconds at full amplitude, then [quiet] seconds at 10%.
Uint8List _wav({required double loud, required double quiet}) {
  const rate = 8000;
  final frames = ((loud + quiet) * rate).round();
  final data = ByteData(44 + frames * 2);
  void tag(int offset, String text) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + frames * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  for (var i = 0; i < frames; i++) {
    final amplitude = i < loud * rate ? 1.0 : 0.1;
    final sample = math.sin(2 * math.pi * 440 * i / rate) * amplitude * 32000;
    data.setInt16(44 + i * 2, sample.round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('wav_peaks_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('outline follows loudness and is scaled to the loudest slice', () async {
    final file = File('${dir.path}/a.wav')..writeAsBytesSync(_wav(loud: 1, quiet: 1));
    final peaks = (await readWavPeaks(file.path, buckets: 20))!;

    expect(peaks, hasLength(20));
    expect(peaks.reduce(math.max), closeTo(1.0, 1e-9));
    expect(peaks.first, closeTo(1.0, 0.05)); // loud half
    expect(peaks.last, closeTo(0.1, 0.03)); // quiet half is a tenth as loud
  });

  test('silence stays silent instead of dividing by zero', () async {
    final file = File('${dir.path}/silent.wav')..writeAsBytesSync(_wav(loud: 0, quiet: 0.5));
    // Quiet part is not silent, so build true silence by zeroing the samples.
    final bytes = _wav(loud: 0, quiet: 0.5);
    for (var i = 44; i < bytes.length; i++) {
      bytes[i] = 0;
    }
    file.writeAsBytesSync(bytes);
    final peaks = (await readWavPeaks(file.path, buckets: 10))!;
    expect(peaks.every((p) => p == 0), isTrue);
  });

  test('rejects files that are not 16-bit PCM WAV', () async {
    final file = File('${dir.path}/not_a_wav.mp3')..writeAsBytesSync(List.filled(100, 7));
    expect(await readWavPeaks(file.path), isNull);
  });
}
