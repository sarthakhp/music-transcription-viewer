/// Represents a single pitch frame from the analysis
class PitchFrame {
  final double time;
  final double frequency;
  final double confidence;
  final double midiPitch;
  final bool isVoiced;

  const PitchFrame({
    required this.time,
    required this.frequency,
    required this.confidence,
    required this.midiPitch,
    required this.isVoiced,
  });

  factory PitchFrame.fromJson(Map<String, dynamic> json) {
    return PitchFrame(
      time: (json['time'] as num).toDouble(),
      frequency: (json['frequency'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      midiPitch: (json['midi_pitch'] as num).toDouble(),
      isVoiced: json['is_voiced'] as bool,
    );
  }
}

/// Metadata about the audio file
class Metadata {
  final String? originalSongPath;
  final String? vocalFilePath;
  final double? bpm;

  const Metadata({
    this.originalSongPath,
    this.vocalFilePath,
    this.bpm,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      originalSongPath: json['original_song_path'] as String?,
      vocalFilePath: json['vocal_file_path'] as String?,
      bpm: (json['bpm'] as num?)?.toDouble(),
    );
  }
}

/// Complete processed frames data structure
class ProcessedFramesData {
  final Metadata metadata;
  final List<PitchFrame> processedFrames;
  final int frameCount;

  const ProcessedFramesData({
    required this.metadata,
    required this.processedFrames,
    required this.frameCount,
  });

  factory ProcessedFramesData.fromJson(Map<String, dynamic> json) {
    final framesJson = json['processed_frames'] as List<dynamic>;
    return ProcessedFramesData(
      metadata: Metadata.fromJson(json['metadata'] as Map<String, dynamic>),
      processedFrames: framesJson
          .map((e) => PitchFrame.fromJson(e as Map<String, dynamic>))
          .toList(),
      frameCount: json['frame_count'] as int,
    );
  }

  /// Get the maximum time in the data
  double get maxTime {
    if (processedFrames.isEmpty) return 0;
    return processedFrames.last.time;
  }

  /// Get the duration formatted as mm:ss
  String get durationFormatted {
    final totalSeconds = maxTime.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get only voiced frames
  List<PitchFrame> get voicedFrames {
    return processedFrames.where((f) => f.isVoiced).toList();
  }

  /// Get min/max frequency for voiced frames
  (double min, double max) get frequencyRange {
    final voiced = voicedFrames;
    if (voiced.isEmpty) return (0, 2000);
    
    double minFreq = double.infinity;
    double maxFreq = 0;
    
    for (final frame in voiced) {
      if (frame.frequency < minFreq) minFreq = frame.frequency;
      if (frame.frequency > maxFreq) maxFreq = frame.frequency;
    }
    
    return (minFreq, maxFreq);
  }
}

