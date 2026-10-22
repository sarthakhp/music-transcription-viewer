import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Plays picked or recorded audio bytes for the upload preview (Android).
class PreviewAudio {
  final AudioPlayer _player = AudioPlayer();
  final void Function() _onEnded;
  File? _file;
  StreamSubscription<PlayerState>? _sub;

  PreviewAudio(Uint8List bytes, String mimeType, this._onEnded) {
    _load(bytes);
  }

  Future<void> _load(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    _file = File('${dir.path}/preview_${DateTime.now().millisecondsSinceEpoch}');
    await _file!.writeAsBytes(bytes, flush: true);
    await _player.setFilePath(_file!.path);
    _sub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
        _onEnded();
      }
    });
  }

  bool get ended => _player.processingState == ProcessingState.completed;
  double get currentTime => _player.position.inMilliseconds / 1000.0;
  set currentTime(double seconds) {
    _player.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  void play() => _player.play();
  void pause() => _player.pause();

  void dispose() {
    _sub?.cancel();
    _player.dispose();
    _file?.delete().catchError((_) => _file!);
  }
}
