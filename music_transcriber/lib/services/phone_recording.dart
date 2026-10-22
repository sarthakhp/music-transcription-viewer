import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_recorder_service.dart';
import 'system_audio_recorder.dart';
import '../utils/web_file_picker.dart';

enum RecordSource { microphone, phoneAudio }

/// A finished recording, ready to upload like a picked file.
class FinishedRecording {
  final WebFilePickerResult file;

  /// Set when the recording came out silent, e.g. the playing app blocks capture.
  final String? warning;
  const FinishedRecording(this.file, {this.warning});
}

/// Drives one recording at a time from either the microphone or the audio
/// other apps are playing, and exposes elapsed time for the UI.
class PhoneRecording extends ChangeNotifier {
  final AudioRecorderService _mic = AudioRecorderService();
  final SystemAudioRecorder _system = SystemAudioRecorder();
  Timer? _ticker;
  RecordSource? _active;
  Duration _elapsed = Duration.zero;

  bool get isRecording => _active != null;
  Duration get elapsed => _elapsed;

  /// False if the user declined a permission prompt.
  Future<bool> start(RecordSource source) async {
    final ok = source == RecordSource.microphone
        ? await _startMic()
        : await _system.start();
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
    try {
      await _mic.start();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<FinishedRecording?> stop() async {
    final source = _active;
    if (source == null) return null;
    _ticker?.cancel();
    _active = null;
    notifyListeners();

    final stamp = DateTime.now().toString().substring(0, 16).replaceAll(':', '.');
    if (source == RecordSource.microphone) {
      final bytes = await _mic.stop();
      if (bytes.isEmpty) return null;
      return FinishedRecording(WebFilePickerResult(bytes, 'Recording $stamp.wav'));
    }
    final result = await _system.stop();
    if (result == null || result.wavBytes.length < 1000) return null;
    return FinishedRecording(
      WebFilePickerResult(result.wavBytes, 'Phone audio $stamp.wav'),
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
    super.dispose();
  }
}
