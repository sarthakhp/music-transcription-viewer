/// Represents a single chord in the analysis
class Chord {
  final double startTime;
  final double endTime;
  final double duration;
  final String chordLabel;
  final double confidence;
  final String root;
  final String quality;
  final String bass;

  const Chord({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.chordLabel,
    required this.confidence,
    required this.root,
    required this.quality,
    required this.bass,
  });

  factory Chord.fromJson(Map<String, dynamic> json) {
    return Chord(
      startTime: (json['start_time'] as num).toDouble(),
      endTime: (json['end_time'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      chordLabel: json['chord_label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      root: json['root'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      bass: json['bass'] as String? ?? '',
    );
  }

  /// Check if this chord is "No Chord" (N)
  bool get isNoChord => chordLabel == 'N';

  /// Get a display-friendly chord label
  String get displayLabel => isNoChord ? 'N/C' : chordLabel;
}

/// Complete chord data structure
class ChordData {
  final double duration;
  final int sampleRate;
  final double tempoBpm;
  final Map<String, dynamic> keyInfo;
  final int numChords;
  final List<Chord> chords;

  const ChordData({
    required this.duration,
    required this.sampleRate,
    required this.tempoBpm,
    required this.keyInfo,
    required this.numChords,
    required this.chords,
  });

  factory ChordData.fromJson(Map<String, dynamic> json) {
    final chordsJson = json['chords'] as List<dynamic>;
    return ChordData(
      duration: (json['duration'] as num).toDouble(),
      sampleRate: (json['sample_rate'] as num).toInt(),
      tempoBpm: (json['tempo_bpm'] as num).toDouble(),
      keyInfo: json['key_info'] as Map<String, dynamic>? ?? {},
      numChords: json['num_chords'] as int,
      chords: chordsJson
          .map((e) => Chord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Get the duration formatted as mm:ss
  String get durationFormatted {
    final totalSeconds = duration.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get chords within a specific time range
  List<Chord> getChordsInRange(double startTime, double endTime) {
    return chords.where((chord) {
      // Include chord if it overlaps with the time range
      return chord.endTime > startTime && chord.startTime < endTime;
    }).toList();
  }

  /// Get unique chord labels (excluding "N")
  Set<String> get uniqueChordLabels {
    return chords
        .where((c) => !c.isNoChord)
        .map((c) => c.chordLabel)
        .toSet();
  }

  /// Get the number of unique chords (excluding "N")
  int get uniqueChordsCount => uniqueChordLabels.length;
}

