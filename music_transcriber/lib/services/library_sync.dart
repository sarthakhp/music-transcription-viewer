import 'dart:async';
import 'package:flutter/widgets.dart';
import 'transcription_api_service.dart';

/// Keeps the song list current without the user doing anything: redraws when
/// a background refresh finds a changed list, and checks again whenever the
/// app comes back to the foreground.
class LibrarySync with WidgetsBindingObserver {
  final TranscriptionApiService _api;
  final VoidCallback _reload;
  StreamSubscription<void>? _updates;

  LibrarySync(this._api, {required VoidCallback reload}) : _reload = reload;

  void start() {
    _updates = _api.libraryUpdates.listen((_) => _reload());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Throws away nothing: a failed check just leaves the saved list showing.
    _api.listJobs(status: 'completed', fresh: true).then((_) {}, onError: (_) {});
  }

  void dispose() {
    _updates?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
