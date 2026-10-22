import 'package:flutter/foundation.dart';
import 'clip_player.dart';
import 'selected_audio.dart';
import 'wav_peaks.dart';

/// The one clip currently being prepared for upload: the file, its length,
/// waveform outline, trim range and a player. Replacing or clearing it deletes
/// the previous file and stops the player, so old takes never linger.
class AudioDraft extends ChangeNotifier {
  static const minSelectionSeconds = 0.5;

  final ClipPlayer player = ClipPlayer();

  SelectedAudio? _audio;
  double _duration = 0;
  double _trimStart = 0;
  double _trimEnd = 0;
  List<double>? _peaks;
  int _generation = 0;

  SelectedAudio? get audio => _audio;
  bool get hasAudio => _audio != null;
  double get duration => _duration;
  double get trimStart => _trimStart;
  double get trimEnd => _trimEnd;
  List<double>? get peaks => _peaks;
  bool get isTrimmed => _trimStart > 0.01 || _trimEnd < _duration - 0.01;

  /// Makes [audio] the current clip, discarding the previous one. Returns false
  /// (and discards [audio]) if it can't be read as audio.
  Future<bool> replaceWith(SelectedAudio audio) async {
    final generation = ++_generation;
    await _discard();
    _audio = audio;
    notifyListeners();

    final duration = await player.load(audio.path);
    final peaks = audio.isWav ? await readWavPeaks(audio.path) : null;
    if (generation != _generation) return false; // superseded meanwhile
    if (duration == null || duration <= 0) {
      await clear();
      return false;
    }
    _duration = duration;
    _trimStart = 0;
    _trimEnd = duration;
    _peaks = peaks;
    player.setRange(_trimStart, _trimEnd);
    notifyListeners();
    return true;
  }

  void setTrim(double start, double end) {
    _trimStart = start.clamp(0, _duration);
    _trimEnd = end.clamp(_trimStart + minSelectionSeconds, _duration);
    player.setRange(_trimStart, _trimEnd);
    notifyListeners();
  }

  Future<void> clear() async {
    _generation++;
    await _discard();
    notifyListeners();
  }

  Future<void> _discard() async {
    await player.stop();
    await _audio?.delete();
    _audio = null;
    _peaks = null;
    _duration = _trimStart = _trimEnd = 0;
  }

  @override
  void dispose() {
    _generation++;
    _audio?.delete();
    player.dispose();
    super.dispose();
  }
}
