part of 'home_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

/// Count-in before playback, so you can play along while practicing.
extension _HomeScreenCountIn on _HomeScreenState {
  /// Single entry point for play/pause from the keyboard, the player controls
  /// and the OS media controls.
  ///
  /// With count-in on, starting from paused counts in first. Pressing play
  /// again during the count cancels it.
  Future<void> _togglePlayback() async {
    if (_countIn.isRunning) {
      _countIn.cancel();
      return;
    }
    final appState = context.read<AppState>();
    if (appState.isPlaying || _countIn.beats == 0) {
      await _audioService.togglePlayPause();
      return;
    }
    final counted = await _countIn.run(
      bpm: appState.pitchData?.metadata.bpm,
      speed: _playbackSpeed,
    );
    if (counted && mounted) await _audioService.togglePlayPause();
  }

  void _setCountInBeats(int beats) {
    _countIn.setBeats(beats);
    _userSettings.saveCountInBeats(beats);
  }
}
