import 'dart:math' as math;
import 'dart:typed_data';

/// Loudness outline of decoded audio: [buckets] values in 0..1, each the
/// average loudness (RMS) of an equal slice across all channels, scaled so the
/// loudest slice is 1. The same measure the phone uses, so both look alike.
List<double> pcmOutline(List<Float32List> channels, {int buckets = 160}) {
  if (channels.isEmpty || channels.first.isEmpty) return List.filled(buckets, 0.0);
  final frames = channels.first.length;
  final perBucket = math.max(1, (frames / buckets).ceil());
  final sumSquares = List<double>.filled(buckets, 0);
  final counts = List<int>.filled(buckets, 0);

  for (final channel in channels) {
    for (var i = 0; i < frames; i++) {
      final bucket = math.min(i ~/ perBucket, buckets - 1);
      final sample = channel[i];
      sumSquares[bucket] += sample * sample;
      counts[bucket]++;
    }
  }

  final levels = [
    for (var i = 0; i < buckets; i++) counts[i] == 0 ? 0.0 : math.sqrt(sumSquares[i] / counts[i]),
  ];
  final loudest = levels.fold<double>(0, math.max);
  return loudest == 0 ? levels : [for (final level in levels) level / loudest];
}
