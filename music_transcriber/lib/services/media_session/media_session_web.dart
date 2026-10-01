import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Shows the track in the OS media UI (Android/iOS notification and lock
/// screen, desktop media keys, Control Center) and routes its buttons to the
/// player. Without this, browsers show a bare page-title entry whose buttons
/// don't control the app.
class MediaSessionController {
  /// Seek step for the skip buttons; matches the in-app ±5s buttons.
  static const double skipSeconds = 5;

  bool _attached = false;

  web.MediaSession? get _session {
    try {
      final nav = web.window.navigator as JSObject;
      if (!nav.has('mediaSession')) return null;
      return web.window.navigator.mediaSession;
    } catch (_) {
      return null;
    }
  }

  void attach({
    required String title,
    required void Function() onPlay,
    required void Function() onPause,
    required void Function(double seconds) onSeekTo,
    required void Function(double deltaSeconds) onSeekBy,
    required void Function() onRestart,
  }) {
    final session = _session;
    if (session == null) return;
    _attached = true;

    updateMetadata(title);

    void handle(String action, JSFunction handler) {
      try {
        session.setActionHandler(action, handler);
      } catch (e) {
        // Some browsers don't support every action; that's fine.
        debugPrint('[MediaSession] action "$action" unsupported: $e');
      }
    }

    handle('play', ((JSObject _) => onPlay()).toJS);
    handle('pause', ((JSObject _) => onPause()).toJS);
    handle('seekbackward', ((JSObject _) => onSeekBy(-skipSeconds)).toJS);
    handle('seekforward', ((JSObject _) => onSeekBy(skipSeconds)).toJS);
    handle('previoustrack', ((JSObject _) => onRestart()).toJS);
    handle(
      'seekto',
      ((JSObject details) {
        final t = details.getProperty<JSAny?>('seekTime'.toJS);
        if (t.isA<JSNumber>()) onSeekTo((t as JSNumber).toDartDouble);
      }).toJS,
    );
  }

  void updateMetadata(String title) {
    final session = _session;
    if (session == null || !_attached) return;
    String abs(String path) => Uri.base.resolve(path).toString();
    session.metadata = web.MediaMetadata(
      web.MediaMetadataInit(
        title: title,
        artist: 'Music Transcriber',
        album: 'Practice',
        artwork: [
          web.MediaImage(src: abs('icons/Icon-192.png'), sizes: '192x192', type: 'image/png'),
          web.MediaImage(src: abs('icons/Icon-512.png'), sizes: '512x512', type: 'image/png'),
        ].toJS,
      ),
    );
  }

  /// Call on play/pause, seek, speed change and when the duration becomes
  /// known. The browser extrapolates the scrubber between calls.
  void updateState({
    required bool playing,
    required double position,
    required double duration,
    required double speed,
  }) {
    final session = _session;
    if (session == null || !_attached) return;
    session.playbackState = playing ? 'playing' : 'paused';
    if (duration.isFinite && duration > 0) {
      try {
        session.setPositionState(
          web.MediaPositionState(
            duration: duration,
            playbackRate: speed,
            position: position.clamp(0.0, duration),
          ),
        );
      } catch (e) {
        debugPrint('[MediaSession] setPositionState failed: $e');
      }
    }
  }

  void detach() {
    final session = _session;
    if (session == null || !_attached) return;
    _attached = false;
    for (final action in const [
      'play', 'pause', 'seekbackward', 'seekforward', 'previoustrack', 'seekto',
    ]) {
      try {
        session.setActionHandler(action, null);
      } catch (_) {}
    }
    session.metadata = null;
    session.playbackState = 'none';
  }
}
