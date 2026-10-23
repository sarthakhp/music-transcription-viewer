import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/services/clip/pcm_outline.dart';

Float32List _constant(double value, int length) => Float32List(length)..fillRange(0, length, value);

void main() {
  test('follows loudness and scales the loudest slice to 1', () {
    final loud = _constant(0.8, 1000);
    final quiet = _constant(0.08, 1000);
    final outline = pcmOutline([Float32List.fromList([...loud, ...quiet])], buckets: 20);

    expect(outline, hasLength(20));
    expect(outline.first, closeTo(1.0, 1e-6));
    expect(outline.last, closeTo(0.1, 1e-3));
  });

  test('averages across channels', () {
    final outline = pcmOutline([_constant(0.5, 400), _constant(0.0, 400)], buckets: 4);
    expect(outline.every((v) => (v - 1.0).abs() < 1e-6), isTrue); // flat, so all equal after scaling
  });

  test('silence and empty input stay silent', () {
    expect(pcmOutline([_constant(0, 100)], buckets: 5).every((v) => v == 0), isTrue);
    expect(pcmOutline([], buckets: 5).every((v) => v == 0), isTrue);
  });
}
