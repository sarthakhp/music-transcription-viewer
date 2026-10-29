import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/pitch_data.dart';
import 'package:music_transcriber/utils/music_utils.dart';
import 'package:music_transcriber/widgets/graph_renderers/pitch_renderer.dart';

PitchFrame _at(double time, int midi) => PitchFrame(
      time: time,
      frequency: 440.0 * _pow2((midi - 69) / 12),
      confidence: 0.9,
      midiPitch: midi.toDouble(),
      isVoiced: true,
    );

double _pow2(double x) => _exp(x * 0.6931471805599453);
double _exp(double x) {
  // e^x via the series; plenty accurate for |x| < 2.
  var term = 1.0, sum = 1.0;
  for (var i = 1; i < 30; i++) {
    term *= x / i;
    sum += term;
  }
  return sum;
}

PitchRenderer _renderer(List<int> midis, {double now = 0}) {
  final frames = [for (var i = 0; i < midis.length; i++) _at(i * 0.1, midis[i])];
  return PitchRenderer(
    data: ProcessedFramesData(metadata: const Metadata(), processedFrames: frames, frameCount: frames.length),
    showUnvoiced: false,
    viewStartTime: 0,
    viewEndTime: 10,
    primaryColor: Colors.teal,
    primaryHighlightColor: Colors.orange,
    unvoicedColor: Colors.grey,
    referenceFrequency: 440,
    minMidi: 40,
    maxMidi: 90,
    currentTime: now,
  );
}

void main() {
  test('frequencyToMidi helper agrees with the test signal', () {
    expect(frequencyToMidi(_at(0, 72).frequency).round(), 72);
  });

  test('lists the next different notes, skipping the one sounding now', () {
    final r = _renderer([69, 69, 69, 69, 72, 72, 72, 74, 74, 74]);
    expect(r.upcomingPitches(), [72, 74]);
  });

  test('a one-frame wobble is not announced as a note', () {
    final r = _renderer([69, 69, 69, 70, 69, 69, 72, 72, 72, 72]);
    expect(r.upcomingPitches(), [72]);
  });

  test('nothing is upcoming when the note never changes', () {
    expect(_renderer([69, 69, 69, 69, 69, 69]).upcomingPitches(), isEmpty);
  });
}
