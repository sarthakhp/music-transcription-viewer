import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/pitch_data.dart';

ProcessedFramesData _data(List<double> frameTimes) => ProcessedFramesData.fromJson({
      'metadata': {'bpm': 120.0},
      'processed_frames': [
        for (final t in frameTimes)
          {'time': t, 'frequency': 440.0, 'confidence': 0.9, 'midi_pitch': 69.0, 'is_voiced': true},
      ],
      'frame_count': frameTimes.length,
    });

void main() {
  test('a song with no voice frames takes its length from the stored duration', () {
    final data = _data([])..declaredDuration = 36.34;
    expect(data.maxTime, 36.34);
    expect(data.durationFormatted, '00:36');
  });

  test('without a stored duration the last voice frame is the length', () {
    expect(_data([0.0, 1.0, 12.5]).maxTime, 12.5);
  });

  test('the longer of the two wins, so a song is never cut short', () {
    final data = _data([0.0, 40.0])..declaredDuration = 36.0;
    expect(data.maxTime, 40.0);
  });

  test('an empty song with no stored duration is zero, not an error', () {
    expect(_data([]).maxTime, 0);
  });
}
