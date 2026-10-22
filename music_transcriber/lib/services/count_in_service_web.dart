import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Plays a short run of metronome clicks before playback starts, so you can
/// come in on the beat when practicing along with a song.
///
/// Clicks are scheduled on the Web Audio clock (sample-accurate) rather than
/// with timers, so the spacing stays even. The interval follows the song's
/// tempo and the current playback speed, so slowing the song down slows the
/// count too.
class CountInService extends ChangeNotifier {
  static const _fallbackBpm = 100.0;
  static const _leadInSeconds = 0.08;

  web.AudioContext? _ctx;
  web.GainNode? _master;
  int _runId = 0;
  bool _running = false;

  int _beats = 0;

  /// Number of clicks before the song starts; 0 means count-in is off.
  int get beats => _beats;

  void setBeats(int value) {
    final clamped = value.clamp(0, 4);
    if (clamped == _beats) return;
    _beats = clamped;
    notifyListeners();
  }

  /// The beat being shown right now (1-based), or null when not counting.
  final ValueNotifier<int?> currentBeat = ValueNotifier(null);

  bool get isRunning => _running;

  /// Counts in, then returns true so the caller can start the song on the
  /// next beat. Returns false if [cancel] was called first.
  Future<bool> run({double? bpm, double speed = 1.0}) async {
    if (_beats <= 0) return true;
    final runId = ++_runId;
    _running = true;
    notifyListeners();

    try {
      final ctx = _ctx ??= web.AudioContext();
      if (ctx.state == 'suspended') await ctx.resume().toDart;
      if (runId != _runId) return false;

      final interval =
          60.0 / ((bpm ?? _fallbackBpm).clamp(30.0, 300.0) * speed.clamp(0.25, 2.0));
      final start = ctx.currentTime + _leadInSeconds;

      final master = _master = ctx.createGain()..connect(ctx.destination);
      for (var i = 0; i < _beats; i++) {
        _scheduleClick(ctx, master, start + i * interval, accent: i == 0);
      }

      for (var i = 0; i < _beats; i++) {
        await _sleepUntil(ctx, start + i * interval);
        if (runId != _runId) return false;
        currentBeat.value = i + 1;
      }
      // The song starts on the beat after the last click.
      await _sleepUntil(ctx, start + _beats * interval);
      return runId == _runId;
    } finally {
      if (runId == _runId) _finish();
    }
  }

  /// Stops a count-in in progress, silencing any clicks not yet played.
  void cancel() {
    if (!_running) return;
    _runId++;
    try {
      _master?.disconnect();
    } catch (_) {}
    _finish();
  }

  void _finish() {
    _running = false;
    currentBeat.value = null;
    notifyListeners();
  }

  void _scheduleClick(
    web.AudioContext ctx,
    web.GainNode out,
    double at, {
    required bool accent,
  }) {
    final osc = ctx.createOscillator()
      ..type = 'sine'
      ..frequency.value = accent ? 1500 : 1000;
    final env = ctx.createGain();
    env.gain.setValueAtTime(0.0001, at);
    env.gain.linearRampToValueAtTime(0.7, at + 0.003);
    env.gain.exponentialRampToValueAtTime(0.0001, at + 0.09);
    osc.connect(env);
    env.connect(out);
    osc.start(at);
    osc.stop(at + 0.1);
  }

  Future<void> _sleepUntil(web.AudioContext ctx, double audioTime) async {
    final ms = ((audioTime - ctx.currentTime) * 1000).round();
    if (ms > 0) await Future<void>.delayed(Duration(milliseconds: ms));
  }

  @override
  void dispose() {
    cancel();
    currentBeat.dispose();
    super.dispose();
  }
}
