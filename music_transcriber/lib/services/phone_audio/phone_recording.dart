import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'selected_audio.dart';
import 'system_audio_recorder.dart';

enum RecordSource { microphone, phoneAudio }

/// A finished recording, as a temp file ready for review and upload.
class FinishedRecording {
  final SelectedAudio audio;

  /// Set when the recording came out silent, e.g. the playing app blocks capture.
  final String? warning;
  const FinishedRecording(this.audio, {this.warning});
}

/// Drives one recording at a time from either the microphone or the audio
/// other apps are playing, and exposes elapsed time for the UI. Recordings go
/// straight to a file, never into memory.
class PhoneRecording extends ChangeNotifier {
  final AudioRecorder _mic = AudioRecorder();
  final SystemAudioRecorder _system = SystemAudioRecorder();
  Timer? _ticker;
  RecordSource? _active;
  Duration _elapsed = Duration.zero;

  bool get isRecording => _active != null;
  Duration get elapsed => _elapsed;

  /// False if the user declined a permission prompt.
  Future<bool> start(RecordSource source) async {
    final ok = source == RecordSource.microphone ? await _startMic() : await _system.start();
    if (!ok) return false;
    _active = source;
    _elapsed = Duration.zero;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  Future<bool> _startMic() async {
    if (!await _mic.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    // Voice processing off, so music and instruments aren't filtered out.
    await _mic.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: '${dir.path}/mic_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    return true;
  }

  Future<FinishedRecording?> stop() async {
    final source = _active;
    if (source == null) return null;
    _ticker?.cancel();
    _active = null;
    notifyListeners();

    final stamp = DateTime.now().toString().substring(0, 16).replaceAll(':', '.');
    if (source == RecordSource.microphone) {
      final path = await _mic.stop();
      if (path == null) return null;
      return FinishedRecording(SelectedAudio(path: path, name: 'Recording $stamp.wav'));
    }
    final result = await _system.stop();
    if (result == null) return null;
    return FinishedRecording(
      SelectedAudio(path: result.path, name: 'Phone audio $stamp.wav'),
      warning: result.looksSilent
          ? 'Nothing was captured. The app you played from may block '
              'recording its audio (some music and video apps do).'
          : null,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_active == RecordSource.microphone) _mic.cancel();
    _mic.dispose();
    super.dispose();
  }
}
