import '../../models/instrument_data.dart';
import '../../models/pitch_data.dart';
import '../../utils/music_utils.dart';

/// The semitone rows (MIDI numbers) a song actually uses: confident voiced
/// frames plus every instrument note. The axis fades the labels of all other
/// rows, so the handful that matter stand out from the full ladder.
Set<int> usedPitchRows(ProcessedFramesData data, InstrumentData? instruments, double referenceFrequency) {
  final rows = <int>{};
  for (final frame in data.processedFrames) {
    if (!frame.isVoiced || frame.frequency <= 0 || frame.confidence < 0.3) continue;
    rows.add(frequencyToMidi(frame.frequency, referenceFrequency: referenceFrequency).round());
  }
  if (instruments != null) {
    for (final track in instruments.tracks.values) {
      for (final note in track.notes) {
        rows.add(note.pitch);
      }
    }
  }
  return rows;
}
