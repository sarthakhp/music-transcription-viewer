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
      if (!appState.isPlaying) _jumpIntoCycleIfOutside();
      await _audioService.togglePlayPause();
      return;
    }
    _jumpIntoCycleIfOutside();
    final counted = await _countIn.run(
      bpm: appState.effectiveBpm,
      speed: _playbackSpeed,
    );
    if (counted && mounted) await _audioService.togglePlayPause();
  }

  void _setCountInBeats(int beats) {
    _countIn.setBeats(beats);
    _userSettings.saveCountInBeats(beats);
    if (beats > 0) _lastCountInBeats = beats;
  }

  /// K: switch the count-in on (with the last used number of clicks) or off.
  void _toggleCountIn() {
    final turningOn = _countIn.beats == 0;
    _setCountInBeats(turningOn ? _lastCountInBeats : 0);
    _showHint(turningOn
        ? 'Count-in: $_lastCountInBeats click${_lastCountInBeats == 1 ? '' : 's'}'
        : 'Count-in off');
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1100),
        behavior: SnackBarBehavior.floating,
        width: 240,
      ));
  }
}
