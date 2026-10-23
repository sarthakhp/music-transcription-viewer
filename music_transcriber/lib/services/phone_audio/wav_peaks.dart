import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// Loudness outline of a 16-bit PCM WAV file: [buckets] values in 0..1, each
/// the average loudness (RMS) of an equal slice of the audio, scaled so the
/// loudest slice is 1. (Taking each slice's single loudest sample instead would
/// make loud, mastered music look like a wall of identical bars.) Read in
/// chunks on a background isolate, so even a long recording never sits in
/// memory or blocks the UI. Returns null for anything that isn't 16-bit PCM WAV.
Future<List<double>?> readWavPeaks(String path, {int buckets = 160}) =>
    Isolate.run(() => _readPeaks(path, buckets));

List<double>? _readPeaks(String path, int buckets) {
  final file = File(path).openSync();
  try {
    final layout = _findData(file);
    if (layout == null) return null;
    final (dataStart, dataLength, channels) = layout;
    final frameBytes = 2 * channels;
    final frames = dataLength ~/ frameBytes;
    if (frames == 0) return null;

    final framesPerBucket = math.max(1, (frames / buckets).ceil());
    final sumSquares = List<double>.filled(buckets, 0);
    final counts = List<int>.filled(buckets, 0);
    file.setPositionSync(dataStart);

    var frame = 0;
    var remaining = dataLength - dataLength % frameBytes;
    while (remaining > 0) {
      final chunk = file.readSync(math.min(remaining, 64 * 1024 - 64 * 1024 % frameBytes));
      if (chunk.isEmpty) break;
      remaining -= chunk.length;
      final samples = chunk.buffer.asByteData(chunk.offsetInBytes, chunk.length);
      for (var i = 0; i + frameBytes <= chunk.length; i += frameBytes, frame++) {
        final bucket = math.min(frame ~/ framesPerBucket, buckets - 1);
        final value = samples.getInt16(i, Endian.little) / 32768.0;
        sumSquares[bucket] += value * value;
        counts[bucket]++;
      }
    }
    return _normalised([
      for (var i = 0; i < buckets; i++) counts[i] == 0 ? 0.0 : math.sqrt(sumSquares[i] / counts[i]),
    ]);
  } finally {
    file.closeSync();
  }
}

List<double> _normalised(List<double> levels) {
  final loudest = levels.fold<double>(0, math.max);
  return loudest == 0 ? levels : [for (final level in levels) level / loudest];
}

/// (data offset, data length, channel count) of a 16-bit PCM WAV, or null.
(int, int, int)? _findData(RandomAccessFile file) {
  final head = file.readSync(12);
  if (head.length < 12 || String.fromCharCodes(head.sublist(0, 4)) != 'RIFF') return null;

  var channels = 0;
  var bits = 0;
  var position = 12;
  final fileLength = file.lengthSync();
  while (position + 8 <= fileLength) {
    file.setPositionSync(position);
    final header = file.readSync(8);
    final id = String.fromCharCodes(header.sublist(0, 4));
    final size = header.buffer.asByteData(header.offsetInBytes, 8).getUint32(4, Endian.little);
    if (id == 'fmt ') {
      final fmt = file.readSync(16).buffer.asByteData();
      channels = fmt.getUint16(2, Endian.little);
      bits = fmt.getUint16(14, Endian.little);
    } else if (id == 'data') {
      if (bits != 16 || channels < 1) return null;
      final start = position + 8;
      return (start, math.min(size, fileLength - start), channels);
    }
    position += 8 + size + (size.isOdd ? 1 : 0);
  }
  return null;
}
