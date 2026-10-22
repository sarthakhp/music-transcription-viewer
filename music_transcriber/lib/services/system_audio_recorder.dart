import 'dart:io';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

/// Result of recording what other apps played.
class SystemAudioResult {
  final Uint8List wavBytes;

  /// Loudest sample (0 to 32767). Near 0 means the playing app blocks capture.
  final int peak;
  const SystemAudioResult(this.wavBytes, this.peak);
  bool get looksSilent => peak < 200;
}

/// Records the audio other apps play (Android 10+), through a native
/// foreground service. The system shows its own "start recording" prompt.
class SystemAudioRecorder {
  static const _channel = MethodChannel('music_transcriber/system_audio');

  static Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Returns false if the user declined a permission prompt.
  Future<bool> start() async {
    // The capture API needs the microphone permission even though no mic is used.
    final mic = AudioRecorder();
    final granted = await mic.hasPermission();
    await mic.dispose();
    if (!granted) return false;
    return await _channel.invokeMethod<bool>('start') ?? false;
  }

  Future<SystemAudioResult?> stop() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('stop');
    final path = result?['path'] as String?;
    if (path == null) return null;
    final file = File(path);
    final bytes = await file.readAsBytes();
    await file.delete();
    return SystemAudioResult(bytes, (result?['peak'] as int?) ?? 0);
  }
}
