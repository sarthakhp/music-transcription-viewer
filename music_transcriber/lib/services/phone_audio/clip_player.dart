import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

/// Plays one local clip for review, confined to a trim range: it starts at the
/// range start and stops (back at the start) when it reaches the range end.
class ClipPlayer extends ChangeNotifier {
  final ja.AudioPlayer _player = ja.AudioPlayer();
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<ja.PlayerState> _stateSub;

  double _rangeStart = 0;
  double _rangeEnd = 0;
  double _position = 0;
  bool _playing = false;

  ClipPlayer() {
    _positionSub = _player.positionStream.listen(_onPosition);
    _stateSub = _player.playerStateStream.listen((s) {
      if (s.playing != _playing) {
        _playing = s.playing;
        notifyListeners();
      }
    });
  }

  double get position => _position;
  bool get playing => _playing;

  /// Loads [path] and returns its length in seconds (null if unreadable).
  Future<double?> load(String path) async {
    final duration = await _player.setFilePath(path);
    _position = 0;
    notifyListeners();
    return duration == null ? null : duration.inMilliseconds / 1000.0;
  }

  void setRange(double start, double end) {
    _rangeStart = start;
    _rangeEnd = end;
    if (_position < start || _position > end) seek(start);
  }

  Future<void> toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_position < _rangeStart || _position >= _rangeEnd - 0.05) await seek(_rangeStart);
    // play() completes only when playback pauses or ends: don't await it.
    unawaited(_player.play());
  }

  Future<void> seek(double seconds) async {
    _position = seconds;
    notifyListeners();
    await _player.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  Future<void> stop() => _player.pause();

  void _onPosition(Duration p) {
    _position = p.inMilliseconds / 1000.0;
    if (_playing && _rangeEnd > 0 && _position >= _rangeEnd) {
      _player.pause();
      seek(_rangeStart);
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub.cancel();
    _stateSub.cancel();
    _player.dispose();
    super.dispose();
  }
}
