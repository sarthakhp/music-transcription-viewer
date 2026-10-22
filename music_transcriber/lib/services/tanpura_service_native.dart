import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Android tanpura drone: loops the bundled G-scale recording with just_audio.
/// Pitch follows the key like the web version (tape-style: speed and pitch
/// scale together by 2^((semitones - 7) / 12)).
class TanpuraService extends ChangeNotifier {
  static const String _assetPath = 'assets/audio/tanpura_g.mp3';
  static const int _recordingBaseSemitone = 7;

  final AudioPlayer _player = AudioPlayer();
  bool _loaded = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  double _volume = 0.1;
  int _semitones = 0;

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  double get volume => _volume;

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    _player.setVolume(_volume);
    notifyListeners();
  }

  void setSemitones(int semitones) {
    if (_semitones == semitones) return;
    _semitones = semitones;
    if (_loaded) _applyRate();
  }

  double _pitchRate() =>
      math.pow(2, (_semitones - _recordingBaseSemitone) / 12.0).toDouble();

  void _applyRate() {
    final rate = _pitchRate();
    _player.setSpeed(rate);
    _player.setPitch(rate);
  }

  Future<void> start() async {
    if (_isPlaying || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      if (!_loaded) {
        await _player.setAsset(_assetPath);
        await _player.setLoopMode(LoopMode.one);
        _loaded = true;
      }
      await _player.setVolume(_volume);
      _applyRate();
      _isPlaying = true;
      // play() completes only when playback pauses/ends; don't await it.
      _player.play();
    } catch (e) {
      debugPrint('TanpuraService start error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void stop() {
    if (!_isPlaying) return;
    _player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
