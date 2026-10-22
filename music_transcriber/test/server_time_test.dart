import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/utils/server_time.dart';

void main() {
  group('parseServerTime', () {
    test('reads a timestamp with no zone marker as UTC', () {
      expect(parseServerTime('2026-10-22T08:57:55').toUtc(),
          DateTime.utc(2026, 10, 22, 8, 57, 55));
    });

    test('respects an explicit Z', () {
      expect(parseServerTime('2026-10-22T08:57:55Z').toUtc(),
          DateTime.utc(2026, 10, 22, 8, 57, 55));
    });

    test('respects an explicit offset', () {
      expect(parseServerTime('2026-10-22T14:27:55+05:30').toUtc(),
          DateTime.utc(2026, 10, 22, 8, 57, 55));
    });

    test('handles fractional seconds without a marker', () {
      expect(parseServerTime('2026-10-22T08:57:55.042901').toUtc(),
          DateTime.utc(2026, 10, 22, 8, 57, 55, 42, 901));
    });
  });
}
