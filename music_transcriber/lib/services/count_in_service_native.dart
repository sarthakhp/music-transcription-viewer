import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Android count-in: plays short generated click sounds, timed with a
/// Stopwatch. Interval follows the song tempo and playback speed, like the web
/// version. Timing is less sample-accurate than Web Audio, but steady.
class CountInService extends ChangeNotifier {
  static const _fallbackBpm = 100.0;
  static const _leadIn = Duration(milliseconds: 80);

  final AudioPlayer _accent = AudioPlayer();
  final AudioPlayer _normal = AudioPlayer();
  bool _ready = false;
  int _runId = 0;
  bool _running = false;
  int _beats = 0;

  int get beats => _beats;

  void setBeats(int value) {
    final clamped = value.clamp(0, 4);
    if (clamped == _beats) return;
    _beats = clamped;
    notifyListeners();
  }

  final ValueNotifier<int?> currentBeat = ValueNotifier(null);

  bool get isRunning => _running;

  Future<void> _prepare() async {
    if (_ready) return;
    await _accent.setAudioSource(_ClickSource(_clickWav(1500)));
    await _normal.setAudioSource(_ClickSource(_clickWav(1000)));
    _ready = true;
  }

  Future<bool> run({double? bpm, double speed = 1.0}) async {
    if (_beats <= 0) return true;
    final runId = ++_runId;
    _running = true;
    notifyListeners();
    try {
      await _prepare();
      if (runId != _runId) return false;
      final intervalMs = (60000.0 /
              ((bpm ?? _fallbackBpm).clamp(30.0, 300.0) * speed.clamp(0.25, 2.0)))
          .round();
      final clock = Stopwatch()..start();
      final first = _leadIn.inMilliseconds;
      for (var i = 0; i < _beats; i++) {
        await _sleepUntil(clock, first + i * intervalMs);
        if (runId != _runId) return false;
        currentBeat.value = i + 1;
        final p = i == 0 ? _accent : _normal;
        await p.seek(Duration.zero);
        p.play();
      }
      await _sleepUntil(clock, first + _beats * intervalMs);
      return runId == _runId;
    } finally {
      if (runId == _runId) _finish();
    }
  }

  void cancel() {
    if (!_running) return;
    _runId++;
    _accent.pause();
    _normal.pause();
    _finish();
  }

  void _finish() {
    _running = false;
    currentBeat.value = null;
    notifyListeners();
  }

  Future<void> _sleepUntil(Stopwatch clock, int ms) async {
    final wait = ms - clock.elapsedMilliseconds;
    if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
  }

  @override
  void dispose() {
    cancel();
    _accent.dispose();
    _normal.dispose();
    currentBeat.dispose();
    super.dispose();
  }
}

/// 90 ms decaying sine click as 16-bit mono 44.1 kHz WAV.
Uint8List _clickWav(double freq) {
  const rate = 44100;
  final n = (rate * 0.09).round();
  final data = ByteData(44 + n * 2);
  void tag(int o, String s) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    final env = math.exp(-t * 45) * math.min(1.0, t / 0.003);
    final s = math.sin(2 * math.pi * freq * t) * env * 0.7;
    data.setInt16(44 + i * 2, (s * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

class _ClickSource extends StreamAudioSource {
  final Uint8List _bytes;
  _ClickSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
