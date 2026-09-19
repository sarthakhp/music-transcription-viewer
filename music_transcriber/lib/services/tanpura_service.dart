import 'dart:async';
import 'dart:math' as math;
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Synthesizes a tanpura drone via Web Audio API.
///
/// Each string pluck is built from additive sine harmonics (not sawtooth)
/// with a natural pluck envelope — fast attack, long resonant decay — giving
/// a warm, realistic tone instead of a harsh buzzing waveform.
///
/// String order: Pa (low), Sa (low), Sa (mid), Sa (high) — traditional tuning.
class TanpuraService extends ChangeNotifier {
  web.AudioContext? _ctx;
  web.GainNode? _masterGain;
  web.DynamicsCompressorNode? _compressor;

  bool _isPlaying = false;
  double _volume = 0.5;
  int _semitones = 0;

  static const double _cycleSeconds = 6.0;
  // Each string rings for most of the cycle
  static const double _noteDuration = 5.0;
  static const double _lookahead = 1.5;

  // Harmonic series: [multiplier, relative_amplitude]
  // Falls off naturally like a plucked string
  static const List<(double, double)> _harmonics = [
    (1.0, 1.00),
    (2.0, 0.55),
    (3.0, 0.28),
    (4.0, 0.14),
    (5.0, 0.08),
    (6.0, 0.04),
    (7.0, 0.02),
  ];

  Timer? _schedulerTimer;
  double _nextCycleTime = 0;

  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    _masterGain?.gain.setTargetAtTime(_volume, _ctx?.currentTime ?? 0, 0.05);
    notifyListeners();
  }

  /// Update pitch — if already playing, restart immediately so the change
  /// is heard right away instead of waiting for the next scheduled cycle.
  void setSemitones(int semitones) {
    if (_semitones == semitones) return;
    _semitones = semitones;
    if (_isPlaying) {
      _stopScheduler();
      _startScheduler();
    }
  }

  Future<void> start() async {
    if (_isPlaying) return;

    _ctx ??= web.AudioContext();
    final ctx = _ctx!;

    if (_compressor == null) {
      _compressor = ctx.createDynamicsCompressor();
      _compressor!.threshold.value = -18;
      _compressor!.knee.value = 10;
      _compressor!.ratio.value = 3;
      _compressor!.attack.value = 0.003;
      _compressor!.release.value = 0.25;
      _compressor!.connect(ctx.destination);
    }

    if (_masterGain == null) {
      _masterGain = ctx.createGain();
      _masterGain!.gain.value = _volume;
      _masterGain!.connect(_compressor!);
    }

    if (ctx.state == 'suspended') {
      await ctx.resume().toDart;
    }

    _isPlaying = true;
    _startScheduler();
    notifyListeners();
  }

  void stop() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _stopScheduler();
    _masterGain?.gain.setTargetAtTime(0, _ctx?.currentTime ?? 0, 0.4);
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    try { _masterGain?.disconnect(); } catch (_) {}
    try { _compressor?.disconnect(); } catch (_) {}
    _masterGain = null;
    _compressor = null;
    super.dispose();
  }

  // --- Scheduling --------------------------------------------------------

  void _startScheduler() {
    if (_ctx == null) return;
    _nextCycleTime = _ctx!.currentTime + 0.05;
    _scheduleCycles();
  }

  void _stopScheduler() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
  }

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
  static const List<double> _timing = [0.0, 0.22, 0.44, 0.66];

  // Slight per-string detuning in cents for natural warmth
  static const List<double> _detunesCents = [0.0, 2.0, -1.5, 1.0];

  void _scheduleOneCycle(double cycleStart) {
    if (_ctx == null || _masterGain == null) return;
    final saBase = 261.63 * math.pow(2, _semitones / 12.0);
    for (int i = 0; i < 4; i++) {
      final t = cycleStart + _timing[i] * _cycleSeconds;
      final freq = saBase
          * math.pow(2, _octaveOffsets[i])
          * math.pow(2, _intervals[i] / 12.0)
          * math.pow(2, _detunesCents[i] / 1200.0);
      _schedulePluck(freq.toDouble(), t);
    }
  }

  void _schedulePluck(double freq, double t) {
    final ctx = _ctx!;
    // Each harmonic is a pure sine — additive synthesis gives a warm,
    // smooth timbre rather than the harsh buzz of a raw sawtooth.
    for (final (mult, amp) in _harmonics) {
      final osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = freq * mult;

      final gain = ctx.createGain();

      // Pluck envelope: sharp attack, long resonant decay
      final peak = _volume * amp * 0.35;
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.linearRampToValueAtTime(peak, t + 0.025);
      // Higher harmonics decay faster (natural string behaviour)
      final decayTau = 1.2 / mult;
      gain.gain.setTargetAtTime(0.0001, t + 0.025, decayTau);

      osc.connect(gain);
      gain.connect(_masterGain!);

      osc.start(t);
      osc.stop(t + _noteDuration);
    }
  }
}
