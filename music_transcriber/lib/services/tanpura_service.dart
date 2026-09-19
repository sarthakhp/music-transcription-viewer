import 'dart:async';
import 'dart:math' as math;
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

/// Plays a real tanpura recording (G scale) as a seamless loop via Web Audio.
/// Pitch is shifted to the current key by adjusting AudioBufferSourceNode.playbackRate.
/// The base recording is in G (semitone 7 from C), so a semitone offset of N
/// plays at rate = 2^((N - 7) / 12).
class TanpuraService extends ChangeNotifier {
  static const String _assetPath = 'assets/audio/tanpura_g.mp3';
  // Recording is in G = semitone 7 (relative to C=0 reference)
  static const int _recordingBaseSemitone = 7;

  web.AudioContext? _ctx;
  web.AudioBuffer? _buffer;
  web.AudioBufferSourceNode? _source;
  web.GainNode? _gainNode;

  bool _isPlaying = false;
  bool _isLoading = false;
  double _volume = 0.5;
  int _semitones = 0; // root + transpose combined

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  double get volume => _volume;

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    _gainNode?.gain.setTargetAtTime(_volume, _ctx?.currentTime ?? 0, 0.05);
    notifyListeners();
  }

  void setSemitones(int semitones) {
    if (_semitones == semitones) return;
    _semitones = semitones;
    if (_isPlaying && _source != null) {
      _source!.playbackRate.setTargetAtTime(
        _pitchRate(), _ctx?.currentTime ?? 0, 0.05);
    }
  }

  double _pitchRate() =>
      math.pow(2, (_semitones - _recordingBaseSemitone) / 12.0).toDouble();

  Future<void> start() async {
    if (_isPlaying || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      _ctx ??= web.AudioContext();
      final ctx = _ctx!;

      if (ctx.state == 'suspended') {
        await ctx.resume().toDart;
      }

      // Load and decode audio asset on first play
      if (_buffer == null) {
        final byteData = await rootBundle.load(_assetPath);
        final bytes = byteData.buffer.asUint8List();
        _buffer = await ctx.decodeAudioData(bytes.buffer.toJS).toDart;
      }

      _gainNode ??= ctx.createGain()..connect(ctx.destination);
      _gainNode!.gain.value = _volume;

      _source = ctx.createBufferSource();
      _source!.buffer = _buffer;
      _source!.loop = true;
      _source!.playbackRate.value = _pitchRate();
      _source!.connect(_gainNode!);
      _source!.start(0);

      _isPlaying = true;
    } catch (e) {
      debugPrint('TanpuraService start error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void stop() {
    if (!_isPlaying) return;
    try {
      _source?.stop(0);
    } catch (_) {}
    _source = null;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    try { _gainNode?.disconnect(); } catch (_) {}
    _gainNode = null;
    super.dispose();
  }
}
