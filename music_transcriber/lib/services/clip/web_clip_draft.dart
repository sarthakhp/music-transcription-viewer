import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../utils/audio_trim_service.dart';
import '../../utils/preview_audio.dart';
import 'clip_draft.dart';
import 'pcm_outline.dart';

/// The clip being prepared in the browser: audio bytes, decoded once for its
/// length and waveform, then played back through the page's audio element.
/// Replacing or clearing it releases the previous bytes and audio element.
class WebClipDraft extends ChangeNotifier implements ClipDraft {
  static const _tick = Duration(milliseconds: 80);

  Uint8List? _bytes;
  String? _name;
  String _mimeType = 'audio/mpeg';
  double _duration = 0;
  double _trimStart = 0;
  double _trimEnd = 0;
  double _position = 0;
  bool _playing = false;
  List<double>? _peaks;
  PreviewAudio? _audio;
  Timer? _ticker;
  int _generation = 0;

  bool get hasClip => _bytes != null;
  Uint8List? get bytes => _bytes;
  String get mimeType => _mimeType;
  @override
  String? get name => _name;
  @override
  double get duration => _duration;
  @override
  double get trimStart => _trimStart;
  @override
  double get trimEnd => _trimEnd;
  @override
  List<double>? get peaks => _peaks;
  @override
  bool get isTrimmed => _trimStart > 0.01 || _trimEnd < _duration - 0.01;
  @override
  double get position => _position;
  @override
  bool get playing => _playing;

  /// Makes this audio the current clip. Returns false (and clears the clip) if
  /// the browser cannot decode it.
  Future<bool> load(Uint8List bytes, String name, String mimeType) async {
    final generation = ++_generation;
    _discard();
    _bytes = bytes;
    _name = name;
    _mimeType = mimeType;
    notifyListeners();

    final decoded = await AudioTrimService.decode(bytes);
    if (generation != _generation) return false; // replaced meanwhile
    if (decoded == null || decoded.duration <= 0) {
      clear();
      return false;
    }
    _duration = decoded.duration;
    _trimStart = 0;
    _trimEnd = decoded.duration;
    _peaks = pcmOutline(decoded.channels);
    _audio = PreviewAudio(bytes, mimeType, _onEnded);
    notifyListeners();
    return true;
  }

  @override
  void setTrim(double start, double end) {
    _trimStart = start.clamp(0, _duration);
    _trimEnd = end.clamp(_trimStart + minTrimSeconds, _duration);
    if (_position < _trimStart || _position > _trimEnd) _moveTo(_trimStart);
    notifyListeners();
  }

  @override
  void resetTrim() => setTrim(0, _duration);

  @override
  Future<void> seek(double seconds) async {
    _moveTo(seconds);
    notifyListeners();
  }

  @override
  Future<void> toggle() async {
    final audio = _audio;
    if (audio == null) return;
    if (_playing) {
      _pause();
    } else {
      if (_position < _trimStart || _position >= _trimEnd - 0.05) _moveTo(_trimStart);
      audio.play();
      _playing = true;
      _ticker = Timer.periodic(_tick, (_) => _follow());
    }
    notifyListeners();
  }

  void clear() {
    _generation++;
    _discard();
    notifyListeners();
  }

  void _follow() {
    final audio = _audio;
    if (audio == null) return;
    _position = audio.currentTime;
    if (_position >= _trimEnd) {
      _pause();
      _moveTo(_trimStart);
    }
    notifyListeners();
  }

  void _onEnded() {
    _pause();
    _moveTo(_trimStart);
    notifyListeners();
  }

  void _moveTo(double seconds) {
    _position = seconds;
    _audio?.currentTime = seconds;
  }

  void _pause() {
    _audio?.pause();
    _ticker?.cancel();
    _ticker = null;
    _playing = false;
  }

  void _discard() {
    _pause();
    _audio?.dispose();
    _audio = null;
    _bytes = null;
    _name = null;
    _peaks = null;
    _duration = _trimStart = _trimEnd = _position = 0;
  }

  @override
  void dispose() {
    _generation++;
    _discard();
    super.dispose();
  }
}
