import 'dart:math' as math;
import 'dart:ui' show Color, FontWeight;

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

// ─── Sargam (Indian classical notation) ─────────────────────────────────────

enum SargamNoteType { shuddh, komal, tivra }

/// Classify each semitone offset (0–11) from Sa.
///   Shuddh: S(0), R(2), G(4), m(5), P(7), D(9), N(11)
///   Komal:  r(1), g(3), d(8), n(10)
///   Tivra:  M(6)
const List<SargamNoteType> sargamNoteTypes = [
  SargamNoteType.shuddh, // 0  Sa
  SargamNoteType.komal,  // 1  komal Re
  SargamNoteType.shuddh, // 2  Re
  SargamNoteType.komal,  // 3  komal Ga
  SargamNoteType.shuddh, // 4  Ga
  SargamNoteType.shuddh, // 5  Ma
  SargamNoteType.tivra,  // 6  tivra Ma
  SargamNoteType.shuddh, // 7  Pa
  SargamNoteType.komal,  // 8  komal Dha
  SargamNoteType.shuddh, // 9  Dha
  SargamNoteType.komal,  // 10 komal Ni
  SargamNoteType.shuddh, // 11 Ni
];

SargamNoteType getSargamNoteType(int semitone) =>
    sargamNoteTypes[((semitone % 12) + 12) % 12];

class SargamStyle {
  final Color color;
  final FontWeight fontWeight;
  final Color? backgroundColor;
  const SargamStyle({required this.color, required this.fontWeight, this.backgroundColor});
}

class SargamTheme {
  static const shuddh = SargamStyle(
    color: Color(0xFFE0E0E0),
    fontWeight: FontWeight.bold,
    backgroundColor: Color(0x22FFFFFF),
  );
  static const komal = SargamStyle(
    color: Color(0xFF90CAF9),
    fontWeight: FontWeight.normal,
  );
  static const tivra = SargamStyle(
    color: Color(0xFFEF9A9A),
    fontWeight: FontWeight.normal,
  );

  static SargamStyle forType(SargamNoteType type) => switch (type) {
    SargamNoteType.shuddh => shuddh,
    SargamNoteType.komal => komal,
    SargamNoteType.tivra => tivra,
  };
}

/// Sargam labels indexed by semitone offset from Sa (0–11).
///   0=Sa  1=komal Re  2=Re  3=komal Ga  4=Ga  5=Ma  6=tivra Ma
///   7=Pa  8=komal Dha 9=Dha 10=komal Ni 11=Ni
const List<String> sargamLabels = [
  'Sa', 're', 'Re', 'ga', 'Ga', 'ma', 'Ma', 'Pa', 'dha', 'Dha', 'ni', 'Ni',
];

/// Full display names for Sargam notes (for tooltips / accessibility).
const List<String> sargamFullNames = [
  'Sa', 'Komal Re', 'Re', 'Komal Ga', 'Ga', 'Ma', 'Tivra Ma',
  'Pa', 'Komal Dha', 'Dha', 'Komal Ni', 'Ni',
];

/// Convert a MIDI note number to a Sargam label, given the root note (0–11,
/// where 0 = C, 2 = D, etc.).
///
/// Octave is indicated by:  plain = middle,  `'` = upper,  `.` = lower
/// relative to octave 4 (middle octave where Sa typically sits).
String midiToSargam(double midi, {required int scaleRoot}) {
  if (midi <= 0) return '-';
  final rounded = midi.round();
  final semitone = ((rounded - scaleRoot) % 12 + 12) % 12;
  final label = sargamLabels[semitone];

  // Octave relative to the "home" octave.
  // Home octave = the octave that contains Sa at or just above MIDI 60 area.
  // We use the octave of the root note closest to middle C (MIDI 60).
  final homeMidi = scaleRoot + 60 - (60 % 12); // Sa in octave 4
  final octaveOffset = ((rounded - homeMidi) / 12).floor();

  if (octaveOffset == 0) return label;
  if (octaveOffset > 0) return "$label${"'" * octaveOffset}";
  return '$label${"." * octaveOffset.abs()}';
}

/// Get the full Sargam name for a MIDI note (e.g. "Komal Re").
String midiToSargamFullName(double midi, {required int scaleRoot}) {
  if (midi <= 0) return '-';
  final rounded = midi.round();
  final semitone = ((rounded - scaleRoot) % 12 + 12) % 12;
  return sargamFullNames[semitone];
}

const List<String> _chromaticFlats = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

/// Transpose a chord label string (e.g. "F#:min", "Bb:maj7") by N semitones.
/// Returns the label unchanged for "N" (no chord) or unrecognised formats.
String transposeChordLabel(String label, int semitones) {
  if (label == 'N' || semitones == 0) return label;
  final match = RegExp(r'^([A-G][#b]?)(:.+)?$').firstMatch(label);
  if (match == null) return label;
  final root = match.group(1)!;
  final quality = match.group(2) ?? '';
  int index = noteNames.indexOf(root);
  bool useFlats = false;
  if (index == -1) {
    index = _chromaticFlats.indexOf(root);
    useFlats = true;
  }
  if (index == -1) return label;
  final newIndex = ((index + semitones) % 12 + 12) % 12;
  return '${(useFlats ? _chromaticFlats : noteNames)[newIndex]}$quality';
}

