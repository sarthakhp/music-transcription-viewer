/// Models for instrument transcription data from the /instruments endpoint
class InstrumentNote {
  final double onset;
  final double offset;
  final double duration;
  final int pitch;      // MIDI note number
  final int velocity;   // 0-127
  final double confidence;

  const InstrumentNote({
    required this.onset,
    required this.offset,
    required this.duration,
    required this.pitch,
    required this.velocity,
    required this.confidence,
  });

  factory InstrumentNote.fromJson(Map<String, dynamic> json) => InstrumentNote(
        onset: (json['onset'] as num).toDouble(),
        offset: (json['offset'] as num).toDouble(),
        duration: (json['duration'] as num).toDouble(),
        pitch: (json['pitch'] as num).toInt(),
        velocity: (json['velocity'] as num).toInt(),
        confidence: (json['confidence'] as num).toDouble(),
      );
}

class InstrumentTrack {
  final String instrument;
  final int numNotes;
  final double duration;
  final List<InstrumentNote> notes;

  const InstrumentTrack({
    required this.instrument,
    required this.numNotes,
    required this.duration,
    required this.notes,
  });

  factory InstrumentTrack.fromJson(Map<String, dynamic> json) => InstrumentTrack(
        instrument: json['instrument'] as String,
        numNotes: (json['num_notes'] as num).toInt(),
        duration: (json['duration'] as num).toDouble(),
        notes: (json['notes'] as List<dynamic>)
            .map((n) => InstrumentNote.fromJson(n as Map<String, dynamic>))
            .toList(),
      );
}

class InstrumentData {
  final String jobId;
  final Map<String, InstrumentTrack> tracks;
  final double duration;
  final int totalNotes;
  final double tempoBpm;

  InstrumentData({
    required this.jobId,
    required this.tracks,
    required this.duration,
    required this.totalNotes,
    required this.tempoBpm,
  });

  InstrumentTrack? get bass => tracks['bass'];
  InstrumentTrack? get other => tracks['other'];

  /// MIDI pitch range across all tracks — computed once and cached
  late final (int min, int max) midiRange = _computeMidiRange();

  (int, int) _computeMidiRange() {
    int lo = 127, hi = 0;
    for (final track in tracks.values) {
      for (final note in track.notes) {
        if (note.pitch < lo) lo = note.pitch;
        if (note.pitch > hi) hi = note.pitch;
      }
    }
    return (lo, hi);
  }

  factory InstrumentData.fromJson(Map<String, dynamic> json) {
    final tracksJson = json['tracks'] as Map<String, dynamic>;
    final tracks = tracksJson.map(
      (key, value) => MapEntry(
        key,
        InstrumentTrack.fromJson(value as Map<String, dynamic>),
      ),
    );
    return InstrumentData(
      jobId: json['job_id'] as String,
      tracks: tracks,
      duration: (json['duration'] as num).toDouble(),
      totalNotes: (json['total_notes'] as num).toInt(),
      tempoBpm: (json['tempo_bpm'] as num).toDouble(),
    );
  }
}
