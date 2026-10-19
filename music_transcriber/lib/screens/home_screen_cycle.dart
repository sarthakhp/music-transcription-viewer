part of 'home_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

/// Cycle (loop) playback, like GarageBand's cycle: a region on the timeline
/// that repeats while it is switched on.
extension _HomeScreenCycle on _HomeScreenState {
  /// Region length when cycle is switched on with none drawn yet, in seconds.
  static const double _defaultRegionSeconds = 8;

  /// Called every frame with the player position. Returns the position to
  /// show: when playback crosses the end of an active cycle it jumps back to
  /// the start. Playback that began after the region's end is left alone, so
  /// seeking past the cycle doesn't trap you in it.
  double _loopCycleIfNeeded(double position) {
    final previous = _lastTickPosition;
    _lastTickPosition = position;
    if (!_cycle.active) return position;
    // `_seekTo` resets the previous position, so a seek never looks like
    // playback crossing the end.
    final crossedEnd = _cycle.contains(previous) && position >= _cycle.end;
    if (!crossedEnd) return position;
    _seekTo(_cycle.start);
    _lastTickPosition = _cycle.start;
    return _cycle.start;
  }

  /// When playback starts with cycle on and the playhead outside the region,
  /// start from the beginning of the region.
  void _jumpIntoCycleIfOutside() {
    if (!_cycle.active) return;
    final time = context.read<AppState>().currentTime;
    if (!_cycle.contains(time)) _seekTo(_cycle.start);
  }

  void _toggleCycle() {
    final appState = context.read<AppState>();
    final maxTime = appState.pitchData?.maxTime ?? 0;
    if (!_cycle.hasRegion) {
      // First use: loop the next few seconds from the playhead.
      final start = appState.currentTime.clamp(0.0, maxTime).toDouble();
      final end = (start + _defaultRegionSeconds).clamp(0.0, maxTime).toDouble();
      _cycle.setRegion(start, end < start + CycleState.minLength ? maxTime : end,
          maxTime: maxTime, enabled: true);
      return;
    }
    _cycle.setEnabled(!_cycle.enabled);
  }

  /// I / O: put the cycle start or end at the playhead.
  void _setCycleEdge({required bool start}) {
    final appState = context.read<AppState>();
    final maxTime = appState.pitchData?.maxTime ?? 0;
    final time = appState.currentTime.clamp(0.0, maxTime).toDouble();
    if (!_cycle.hasRegion) {
      final a = start ? time : (time - _defaultRegionSeconds).clamp(0.0, maxTime).toDouble();
      final b = start ? (time + _defaultRegionSeconds).clamp(0.0, maxTime).toDouble() : time;
      _cycle.setRegion(a, b, maxTime: maxTime, enabled: true);
    } else if (start) {
      _cycle.setStart(time);
    } else {
      _cycle.setEnd(time, maxTime: maxTime);
    }
  }

  void _setBpm(double? bpm) {
    context.read<AppState>().setBpmOverride(bpm);
    _debouncedSaveJobSettings();
  }
}
