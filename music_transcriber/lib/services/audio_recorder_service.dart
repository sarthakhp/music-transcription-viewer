import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Wraps the browser MediaRecorder API.
///
/// Usage:
///   final recorder = AudioRecorderService();
///   await recorder.start();      // requests mic + begins recording
///   final bytes = await recorder.stop(); // stops and returns webm bytes
class AudioRecorderService {
  web.MediaStream? _stream;
  web.MediaRecorder? _recorder;
  final List<web.Blob> _chunks = [];

  bool get isRecording => _recorder != null;
  String get mimeType => _recorder?.mimeType ?? 'audio/webm';
  String? get micLabel => _stream?.getAudioTracks().toDart.firstOrNull?.label;

  /// Request microphone access and start recording.
  /// Throws if permission is denied or MediaRecorder is unavailable.
  Future<void> start() async {
    _chunks.clear();

    // Disable browser audio processing so music/instruments aren't filtered out.
    final audioConstraints = _buildAudioConstraints();
    final constraints = web.MediaStreamConstraints(audio: audioConstraints);
    _stream =
        await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;

    final tracks = _stream!.getAudioTracks().toDart;
    debugPrint('[Recorder] mic acquired — tracks: ${tracks.length}');
    for (final t in tracks) {
      debugPrint('[Recorder]   track: label="${t.label}" readyState=${t.readyState} enabled=${t.enabled} muted=${t.muted}');
    }

    final mimeType = _preferredMimeType();
    debugPrint('[Recorder] selected MIME type: "$mimeType"');
    final options = web.MediaRecorderOptions(mimeType: mimeType);
    _recorder = web.MediaRecorder(_stream!, options);
    debugPrint('[Recorder] MediaRecorder state: ${_recorder!.state}');

    int chunkCount = 0;
    _recorder!.addEventListener(
      'dataavailable',
      ((web.Event event) {
        final blobEvent = event as web.BlobEvent;
        chunkCount++;
        debugPrint('[Recorder] chunk #$chunkCount size=${blobEvent.data.size}');
        if (blobEvent.data.size > 0) {
          _chunks.add(blobEvent.data);
        }
      }).toJS,
    );

    // Collect data every 250 ms so we get partial chunks and can show progress.
    _recorder!.start(250);
    debugPrint('[Recorder] recording started');
  }

  /// Stop recording and return the captured audio as bytes.
  Future<Uint8List> stop() async {
    if (_recorder == null) return Uint8List(0);

    final completer = Completer<Uint8List>();

    _recorder!.addEventListener(
      'stop',
      ((web.Event _) {
        final mimeType = _recorder?.mimeType ?? 'audio/webm';
        debugPrint('[Recorder] stopped — chunks collected: ${_chunks.length}, mimeType: "$mimeType"');
        final parts = <JSAny>[for (final c in _chunks) c].toJS;
        final blob = web.Blob(parts, web.BlobPropertyBag(type: mimeType));
        debugPrint('[Recorder] blob size: ${blob.size}');
        blob.arrayBuffer().toDart.then((ab) {
          final bytes = Uint8List.fromList(Uint8List.view(ab.toDart));
          debugPrint('[Recorder] final bytes: ${bytes.length}');
          completer.complete(bytes);
        }).catchError((Object e) {
          debugPrint('[Recorder] ERROR converting blob: $e');
          completer.completeError(e);
        });
      }).toJS,
    );

    _recorder!.stop();
    _stopTracks();

    return completer.future;
  }

  /// Cancel recording without returning data.
  void cancel() {
    _recorder?.stop();
    _stopTracks();
    _chunks.clear();
    _recorder = null;
    _stream = null;
  }

  void _stopTracks() {
    final tracks = _stream?.getTracks().toDart ?? [];
    for (final t in tracks) {
      t.stop();
    }
    _stream = null;
    _recorder = null;
  }

  /// Build audio constraints that disable browser processing (noise suppression,
  /// echo cancellation, auto-gain) so music signals are captured faithfully.
  static JSAny _buildAudioConstraints() {
    // Use MediaTrackConstraints directly; fall back to bare `true` if unsupported.
    try {
      final c = web.MediaTrackConstraints();
      c.echoCancellation = false.toJS;
      c.noiseSuppression = false.toJS;
      c.autoGainControl = false.toJS;
      return c as JSAny;
    } catch (_) {
      return true.toJS;
    }
  }

  /// Pick a MIME type the browser supports (prefers webm/opus, falls back to webm).
  static String _preferredMimeType() {
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/ogg',
      'audio/mp4',
    ];
    for (final mime in candidates) {
      if (web.MediaRecorder.isTypeSupported(mime)) return mime;
    }
    return '';
  }
}
