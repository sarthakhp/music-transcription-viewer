import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Android microphone recorder. Same surface as the web recorder; captures
/// uncompressed WAV with all voice processing off so music isn't filtered.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;
  bool _recording = false;

  bool get isRecording => _recording;
  String get mimeType => 'audio/wav';
  String? get micLabel => null;

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission denied');
    }
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: _path!,
    );
    _recording = true;
  }

  Future<Uint8List> stop() async {
    final path = await _recorder.stop();
    _recording = false;
    if (path == null) return Uint8List(0);
    final file = File(path);
    final bytes = await file.readAsBytes();
    await file.delete();
    return bytes;
  }

  void cancel() {
    _recording = false;
    _recorder.cancel();
  }
}
