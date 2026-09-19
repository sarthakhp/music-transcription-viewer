import 'dart:async';
import 'dart:math' as math;
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Synthesizes a tanpura drone via Web Audio API.
///
/// Plays 4 strings in sequence (Pa, Sa, Sa, Sa — traditional tanpura tuning)
/// using sawtooth oscillators with ADSR envelopes scheduled precisely on the
/// AudioContext clock. Shares the app's existing AudioContext.
class TanpuraService extends ChangeNotifier {
  web.AudioContext? _ctx;
  web.GainNode? _masterGain;

  bool _isPlaying = false;
  double _volume = 0.5;
  int _semitones = 0;

  static const double _cycleSeconds = 6.0;
  static const double _noteDuration = 4.5;
  static const double _lookahead = 1.5;

  Timer? _schedulerTimer;
  double _nextCycleTime = 0;

  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    _masterGain?.gain.setTargetAtTime(_volume, _ctx?.currentTime ?? 0, 0.05);
    notifyListeners();
  }

  void setSemitones(int semitones) {
    _semitones = semitones;
  }

  Future<void> start() async {
    if (_isPlaying) return;

    _ctx ??= web.AudioContext();
    final ctx = _ctx!;

    if (_masterGain == null) {
      _masterGain = ctx.createGain();
      _masterGain!.gain.value = _volume;
      _masterGain!.connect(ctx.destination);
    }

    if (ctx.state == 'suspended') {
      await ctx.resume().toDart;
    }

    _isPlaying = true;
    _nextCycleTime = ctx.currentTime + 0.1;
    _scheduleCycles();
    notifyListeners();
  }

  void stop() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _masterGain?.gain.setTargetAtTime(0, _ctx?.currentTime ?? 0, 0.3);
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    try { _masterGain?.disconnect(); } catch (_) {}
    _masterGain = null;
    super.dispose();
  }

  // --- Scheduling --------------------------------------------------------

  void _scheduleCycles() {
    if (!_isPlaying || _ctx == null) return;

    final now = _ctx!.currentTime;
    while (_nextCycleTime < now + _lookahead) {
      _scheduleOneCycle(_nextCycleTime);
      _nextCycleTime += _cycleSeconds;
    }

    _schedulerTimer = Timer(
      Duration(milliseconds: (_lookahead * 500).round()),
      _scheduleCycles,
    );
  }

  // Pa (low), Sa (low), Sa (mid), Sa (high) — traditional tanpura order
  static const List<int> _intervals = [7, 0, 12, 12];
  static const List<double> _octaveOffsets = [-1.0, -1.0, 0.0, 0.0];
  static const List<double> _timing = [0.0, 0.25, 0.5, 0.75];

  void _scheduleOneCycle(double cycleStart) {
    if (_ctx == null || _masterGain == null) return;
    final saBase = 261.63 * math.pow(2, _semitones / 12.0);
    for (int i = 0; i < 4; i++) {
      final t = cycleStart + _timing[i] * _cycleSeconds;
      final freq = saBase
          * math.pow(2, _octaveOffsets[i])
          * math.pow(2, _intervals[i] / 12.0);
      _schedulePluck(freq.toDouble(), t);
    }
  }

  void _schedulePluck(double freq, double t) {
    final ctx = _ctx!;
    final osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.value = freq;
    osc.detune.value = 2.0; // slight warmth

    final filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 1800;
    filter.Q.value = 0.7;

    final gain = ctx.createGain();
    gain.gain.setValueAtTime(0, t);
    gain.gain.linearRampToValueAtTime(_volume * 0.6, t + 0.08);
    gain.gain.setTargetAtTime(_volume * 0.35, t + 0.08, 0.4);
    gain.gain.setTargetAtTime(0.0001, t + 1.5, 1.2);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(_masterGain!);

    osc.start(t);
    osc.stop(t + _noteDuration);
  }
}
