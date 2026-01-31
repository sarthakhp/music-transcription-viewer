import 'dart:math' as math;

/// Music utility functions for MIDI and frequency conversions

const List<String> noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// Convert MIDI pitch number to note name (e.g., 60 → C4, 69 → A4)
String midiToNoteName(double midi) {
  if (midi <= 0) return '-';
  final roundedMidi = midi.round();
  final octave = (roundedMidi ~/ 12) - 1;
  final noteIndex = roundedMidi % 12;
  return '${noteNames[noteIndex]}$octave';
}

/// Convert frequency (Hz) to MIDI pitch number
/// [referenceFrequency] is the frequency of A4 (default 440 Hz)
double frequencyToMidi(double frequency, {double referenceFrequency = 440.0}) {
  if (frequency <= 0) return 0;
  return 69 + 12 * (math.log(frequency / referenceFrequency) / math.ln2);
}

/// Convert MIDI pitch number to frequency (Hz)
/// [referenceFrequency] is the frequency of A4 (default 440 Hz)
double midiToFrequency(double midi, {double referenceFrequency = 440.0}) {
  return referenceFrequency * math.pow(2.0, (midi - 69) / 12).toDouble();
}

/// Format time in seconds to mm:ss format
String formatTime(double seconds) {
  final totalSeconds = seconds.round();
  final minutes = totalSeconds ~/ 60;
  final secs = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

/// Format time in seconds to mm:ss.ms format
String formatTimeWithMs(double seconds) {
  final minutes = seconds ~/ 60;
  final secs = (seconds % 60).toStringAsFixed(1);
  return '${minutes.toString().padLeft(2, '0')}:${secs.padLeft(4, '0')}';
}

/// Get piano key color (white or black)
bool isBlackKey(int midiNote) {
  final noteInOctave = midiNote % 12;
  return [1, 3, 6, 8, 10].contains(noteInOctave);
}

/// Get frequency range for typical vocal range
(double min, double max) get typicalVocalRange => (80.0, 1000.0);

/// Get MIDI range for typical vocal range (E2 to C6)
(int min, int max) get typicalVocalMidiRange => (40, 84);

