import 'dart:typed_data';
import 'transcription_api_service.dart';

/// The three audio stems for a job, as downloaded from the backend.
///
/// A stem is `null` if the backend didn't have it or the download failed —
/// callers decide how much of that to tolerate (see [primaryBytes]).
class AudioStemsResult {
  final Uint8List? original;
  final Uint8List? vocals;
  final Uint8List? instrumental;

  const AudioStemsResult({this.original, this.vocals, this.instrumental});

  /// The stem to use as the "main" audio track for playback and export.
  /// Vocals are preferred (they carry the pitch being visualized); original
  /// is the fallback when vocal separation wasn't available for this job.
  Uint8List? get primaryBytes => vocals ?? original;

  /// Filename to pair with [primaryBytes], given the job's own input filename.
  String primaryFileName(String? inputFilename) {
    if (inputFilename != null) return inputFilename;
    return vocals != null ? 'vocals.mp3' : 'original.mp3';
  }
}

/// Downloads all three stems for [jobId] in parallel. Never throws — a failed
/// or missing stem just comes back `null` on the corresponding field.
Future<AudioStemsResult> fetchAudioStems(
  TranscriptionApiService apiService,
  String jobId,
) async {
  final stems = await apiService.downloadAllStems(jobId);
  return AudioStemsResult(
    original: stems['original']!.isSuccess ? stems['original']!.data : null,
    vocals: stems['vocals']!.isSuccess ? stems['vocals']!.data : null,
    instrumental: stems['instrumental']!.isSuccess ? stems['instrumental']!.data : null,
  );
}
