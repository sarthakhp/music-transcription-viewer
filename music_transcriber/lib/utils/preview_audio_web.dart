import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Plays picked or recorded audio bytes for the upload preview (web).
class PreviewAudio {
  final web.HTMLAudioElement _audio;
  final String _blobUrl;
  final JSFunction _onEnded;

  PreviewAudio._(this._audio, this._blobUrl, this._onEnded);

  factory PreviewAudio(Uint8List bytes, String mimeType, void Function() onEnded) {
    final blob = web.Blob(
      [bytes.buffer.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final audio = web.document.createElement('audio') as web.HTMLAudioElement
      ..src = url
      ..preload = 'auto';
    final handler = ((web.Event _) => onEnded()).toJS;
    audio.addEventListener('ended', handler);
    web.document.body!.append(audio);
    return PreviewAudio._(audio, url, handler);
  }

  bool get ended => _audio.ended;
  double get currentTime => _audio.currentTime;
  set currentTime(double seconds) => _audio.currentTime = seconds;
  void play() => _audio.play();
  void pause() => _audio.pause();

  void dispose() {
    _audio.pause();
    _audio.removeEventListener('ended', _onEnded);
    _audio.removeAttribute('src');
    _audio.remove();
    web.URL.revokeObjectURL(_blobUrl);
  }
}
