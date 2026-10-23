import 'dart:async';
import '../../models/audio_content_type.dart';
import 'cloud_upload.dart';
import 'submission_tracker.dart';

/// The one upload queue for the whole app: the sign-in, the submissions being
/// followed, and a way to ask for a song to be processed again. The upload card
/// and the song list both use it, so a request made from either appears in the
/// same list and refreshes the song list when it finishes.
class UploadQueue {
  UploadQueue._() {
    tracker = SubmissionTracker(cloud.status, onJobFinished: () => _finished.add(null));
  }

  static final UploadQueue instance = UploadQueue._();

  final CloudUpload cloud = CloudUpload();
  late final SubmissionTracker tracker;
  final StreamController<void> _finished = StreamController<void>.broadcast();
  bool _restored = false;

  /// Fires whenever a submission finishes successfully.
  Stream<void> get jobFinished => _finished.stream;

  /// Loads the remembered submissions once, however many screens ask.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    await tracker.restore();
  }

  /// Asks for the song [sourceJobId] to be processed again, as a new song, with
  /// these settings, and starts following it. [label] is what the list shows
  /// until the worker reports the new song's name.
  Future<void> reprocess({
    required String sourceJobId,
    required String label,
    required AudioContentType audioType,
    required List<String> instruments,
  }) async {
    final id = await cloud.submitReprocess(
      sourceJobId: sourceJobId,
      label: label,
      audioType: audioType,
      instruments: instruments,
    );
    await tracker.add(id, label);
  }
}
