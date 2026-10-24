import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/pitch_data.dart';
import 'package:music_transcriber/widgets/graph_renderers/used_pitch_rows.dart';

PitchFrame _frame(double hz, {double confidence = 0.9, bool voiced = true}) => PitchFrame(
      time: 0, frequency: hz, confidence: confidence, midiPitch: 0, isVoiced: voiced);

void main() {
  test('only confident voiced frames count as rows the song uses', () {
    final data = ProcessedFramesData(
      metadata: const Metadata(),
      processedFrames: [
        _frame(440), // A4 = 69
        _frame(440.5), // still 69
        _frame(880, confidence: 0.1), // too unsure
        _frame(220, voiced: false), // not voiced
        _frame(0), // no pitch
      ],
      frameCount: 5,
    );
    expect(usedPitchRows(data, null, 440.0), {69});
  });
}
