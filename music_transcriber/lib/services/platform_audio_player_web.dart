import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'platform_audio_player.dart';

// --- SoundTouchNode JS interop ----------------------------------------------

/// Dart binding for SoundTouchNode (exposed globally via ESM shim in index.html).
/// SoundTouchNode extends AudioWorkletNode in JS.
@JS('SoundTouchNode')
extension type SoundTouchNodeJS._(JSObject _) implements web.AudioWorkletNode {
  external SoundTouchNodeJS(web.AudioContext context);

  external static JSPromise<JSAny?> register(
    web.AudioContext context,
    String processorUrl,
  );

  external web.AudioParam get pitch;
  external web.AudioParam get pitchSemitones;
  external web.AudioParam get tempo;
  external web.AudioParam get rate;
  external web.AudioParam get playbackRate;
}

/// Checks if SoundTouchNode is available on globalThis.
@JS('SoundTouchNode')
external JSObject? get _soundTouchNodeClass;

// --- Shared AudioContext ----------------------------------------------------

/// Shared AudioContext across all WebAudioPlayer instances.
/// Created lazily on first use, resumed on user gesture.
web.AudioContext? _sharedContext;
bool _workletRegistered = false;

Future<web.AudioContext> _getOrCreateContext() async {
  if (_sharedContext != null) return _sharedContext!;
  _sharedContext = web.AudioContext();
  return _sharedContext!;
}

Future<void> _ensureWorkletRegistered(web.AudioContext ctx) async {
  if (_workletRegistered) return;
  if (_soundTouchNodeClass == null) {
    return;
  }
  try {
    await SoundTouchNodeJS.register(ctx, 'soundtouch-processor.js').toDart;
    _workletRegistered = true;
  } catch (e) {
  }
}

// --- Video platform views ---------------------------------------------------

/// Each loaded video gets a fresh view type registered with Flutter's
/// platform view registry, so `HtmlElementView(viewType: ...)` can display
/// the exact `<video>` element this player is already using for audio.
int _nextVideoViewId = 0;

String _registerVideoView(web.HTMLMediaElement element) {
  final viewType = 'practice-video-${_nextVideoViewId++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _, {Object? params}) => element);
  return viewType;
}

// --- WebAudioPlayer ---------------------------------------------------------

class WebAudioPlayer implements PlatformAudioPlayer {
  web.HTMLMediaElement? _media;
  web.AudioContext? _ctx;
  web.MediaElementAudioSourceNode? _source;
  SoundTouchNodeJS? _stNode;
  String? _blobUrl;
  String? _videoViewType;

  bool _isPlaying = false;
  AudioPlayerState _state = AudioPlayerState.idle;
  int _currentSemitones = 0;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _stateController = StreamController<AudioPlayerState>.broadcast();

  // Store JS callback references so we can remove them on dispose.
  JSFunction? _onTimeUpdate;
  JSFunction? _onLoadedMetadata;
  JSFunction? _onCanPlay;
  JSFunction? _onEnded;
  JSFunction? _onWaiting;
  JSFunction? _onPlaying;
  JSFunction? _onPause;
  JSFunction? _onError;

  @override
  Stream<Duration> get positionStream => _positionController.stream;
  @override
  Stream<Duration?> get durationStream => _durationController.stream;
  @override
  Stream<bool> get playingStream => _playingController.stream;
  @override
  Stream<AudioPlayerState> get stateStream => _stateController.stream;

  @override
  Duration get position {
    if (_media == null) return Duration.zero;
    return Duration(milliseconds: (_media!.currentTime * 1000).round());
  }

  @override
  Duration? get duration {
    if (_media == null) return null;
    final d = _media!.duration;
    if (d.isNaN || d.isInfinite) return null;
    return Duration(milliseconds: (d * 1000).round());
  }

  @override
  bool get playing => _isPlaying;

  @override
  AudioPlayerState get state => _state;

  @override
  String? get videoViewType => _videoViewType;

  // --- Loading --------------------------------------------------------------

  @override
  Future<void> load(Uint8List bytes, String mimeType) async {
    // Clean up previous element if any.
    await _teardownGraph();

    _setState(AudioPlayerState.loading);

    // Create blob URL.
    final blob = web.Blob(
      [bytes.buffer.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    _blobUrl = web.URL.createObjectURL(blob);

    final isVideo = mimeType.startsWith('video/');

    // Create <audio> or <video> element — both implement HTMLMediaElement,
    // so everything below (graph wiring, playback, events) is identical
    // either way.
    _media = web.document.createElement(isVideo ? 'video' : 'audio')
        as web.HTMLMediaElement;
    _media!.preload = 'auto';

    if (isVideo) {
      final video = _media! as web.HTMLVideoElement;
      // Avoid iOS/Android taking over with native fullscreen playback —
      // we drive playback via our own Flutter controls.
      video.setAttribute('playsinline', 'true');
      video.style.width = '100%';
      video.style.height = '100%';
      video.style.objectFit = 'contain';
      _videoViewType = _registerVideoView(_media!);
    }

    // Append to DOM (detached media elements have inconsistent behavior).
    // For video this is later re-parented into place by Flutter's platform
    // view compositor when HtmlElementView builds — a normal, state-
    // preserving DOM move, not a destroy/recreate.
    web.document.body!.append(_media!);

    // Set up event listeners BEFORE setting src.
    _setupEventListeners();

    _media!.src = _blobUrl!;

    // Wait for the element to be ready.
    final readyCompleter = Completer<void>();
    late JSFunction onReady;
    late JSFunction onErr;
    onReady = ((web.Event _) {
      if (!readyCompleter.isCompleted) readyCompleter.complete();
    }).toJS;
    onErr = ((web.Event _) {
      if (!readyCompleter.isCompleted) {
        readyCompleter.completeError('Audio load error');
      }
    }).toJS;
    _media!.addEventListener('canplay', onReady);
    _media!.addEventListener('error', onErr);

    try {
      await readyCompleter.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[WebAudioPlayer] canplay/error wait failed: $e');
      _setState(AudioPlayerState.idle);
      rethrow;
    } finally {
      _media!.removeEventListener('canplay', onReady);
      _media!.removeEventListener('error', onErr);
    }

    await _fixInfiniteDuration();

    // Set up Web Audio graph.
    await _setupGraph();

    _setState(AudioPlayerState.ready);
    _durationController.add(duration);
  }

  /// Some mp3 elementary streams (e.g. extracted from a fragmented MP4/DASH
  /// source, as with common yt-dlp-style rips) don't carry the header info
  /// Chrome needs to report duration up front — `duration` reads Infinity
  /// until the element is seeked near the end and back. This forces that.
  Future<void> _fixInfiniteDuration() async {
    final media = _media;
    if (media == null) return;
    final d = media.duration;
    if (!d.isNaN && !d.isInfinite) return;

    final completer = Completer<void>();
    late JSFunction onTimeUpdate;
    onTimeUpdate = ((web.Event _) {
      media.removeEventListener('timeupdate', onTimeUpdate);
      media.currentTime = 0;
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    media.addEventListener('timeupdate', onTimeUpdate);
    media.currentTime = 1e101;

    try {
      await completer.future.timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[WebAudioPlayer] _fixInfiniteDuration: timed out waiting for timeupdate: $e');
      media.removeEventListener('timeupdate', onTimeUpdate);
    }
  }

  // --- Web Audio Graph ------------------------------------------------------

  Future<void> _setupGraph() async {
    _ctx = await _getOrCreateContext();
    await _ensureWorkletRegistered(_ctx!);

    // createMediaElementSource can only be called once per element per context.
    _source = _ctx!.createMediaElementSource(_media!);

    // Try to create SoundTouchNode for pitch shifting.
    if (_workletRegistered && _soundTouchNodeClass != null) {
      try {
        _stNode = SoundTouchNodeJS(_ctx!);
        _stNode!.pitchSemitones.value = _currentSemitones.toDouble();
        _source!.connect(_stNode!);
        _stNode!.connect(_ctx!.destination);
      } catch (e) {
        _stNode = null;
        _source!.connect(_ctx!.destination);
      }
    } else {
      _source!.connect(_ctx!.destination);
    }
  }

  Future<void> _teardownGraph() async {
    _removeEventListeners();
    _isPlaying = false;

    if (_media != null) {
      _media!.pause();
      _media!.removeAttribute('src');
      _media!.remove();
      _media = null;
    }
    _videoViewType = null;

    // Disconnect nodes (don't close shared context).
    try {
      _stNode?.disconnect();
    } catch (_) {}
    try {
      _source?.disconnect();
    } catch (_) {}
    _stNode = null;
    _source = null;
    _ctx = null; // Release reference but don't close shared context.

    if (_blobUrl != null) {
      web.URL.revokeObjectURL(_blobUrl!);
      _blobUrl = null;
    }
  }

  // --- Event Listeners ------------------------------------------------------

  void _setupEventListeners() {
    final media = _media!;

    _onTimeUpdate = ((web.Event _) {
      _positionController.add(position);
    }).toJS;

    _onLoadedMetadata = ((web.Event _) {
      _durationController.add(duration);
    }).toJS;

    _onCanPlay = ((web.Event _) {
      if (_state == AudioPlayerState.buffering) {
        _setState(AudioPlayerState.ready);
      }
    }).toJS;

    _onEnded = ((web.Event _) {
      _isPlaying = false;
      _playingController.add(false);
      _setState(AudioPlayerState.completed);
    }).toJS;

    _onWaiting = ((web.Event _) {
      _setState(AudioPlayerState.buffering);
    }).toJS;

    _onPlaying = ((web.Event _) {
      _isPlaying = true;
      _playingController.add(true);
      if (_state != AudioPlayerState.ready) {
        _setState(AudioPlayerState.ready);
      }
    }).toJS;

    _onPause = ((web.Event _) {
      // Don't update if ended (we handle that in _onEnded).
      if (_state != AudioPlayerState.completed) {
        _isPlaying = false;
        _playingController.add(false);
      }
    }).toJS;

    _onError = ((web.Event event) {
      final err = _media?.error;
      _isPlaying = false;
      _playingController.add(false);
      _setState(AudioPlayerState.idle);
    }).toJS;

    media.addEventListener('timeupdate', _onTimeUpdate!);
    media.addEventListener('loadedmetadata', _onLoadedMetadata!);
    media.addEventListener('canplay', _onCanPlay!);
    media.addEventListener('ended', _onEnded!);
    media.addEventListener('waiting', _onWaiting!);
    media.addEventListener('playing', _onPlaying!);
    media.addEventListener('pause', _onPause!);
    media.addEventListener('error', _onError!);
  }

  void _removeEventListeners() {
    final media = _media;
    if (media == null) return;

    if (_onTimeUpdate != null) media.removeEventListener('timeupdate', _onTimeUpdate!);
    if (_onLoadedMetadata != null) media.removeEventListener('loadedmetadata', _onLoadedMetadata!);
    if (_onCanPlay != null) media.removeEventListener('canplay', _onCanPlay!);
    if (_onEnded != null) media.removeEventListener('ended', _onEnded!);
    if (_onWaiting != null) media.removeEventListener('waiting', _onWaiting!);
    if (_onPlaying != null) media.removeEventListener('playing', _onPlaying!);
    if (_onPause != null) media.removeEventListener('pause', _onPause!);
    if (_onError != null) media.removeEventListener('error', _onError!);

    _onTimeUpdate = null;
    _onLoadedMetadata = null;
    _onCanPlay = null;
    _onEnded = null;
    _onWaiting = null;
    _onPlaying = null;
    _onPause = null;
    _onError = null;
  }

  // --- Playback -------------------------------------------------------------

  @override
  Future<void> play() async {
    if (_media == null) return;

    // Resume AudioContext if suspended (needs user gesture chain).
    if (_ctx != null && _ctx!.state == 'suspended') {
      await _ctx!.resume().toDart;
    }

    try {
      await _media!.play().toDart;
    } catch (e) {
    }
  }

  @override
  Future<void> pause() async {
    _media?.pause();
  }

  @override
  Future<void> stop() async {
    if (_media == null) return;
    _media!.pause();
    _media!.currentTime = 0;
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_media == null) return;
    final wasCompleted = _state == AudioPlayerState.completed;
    _media!.currentTime = position.inMilliseconds / 1000.0;
    _positionController.add(position);
    if (wasCompleted) {
      _setState(AudioPlayerState.ready);
      await play();
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_media == null) return;
    _media!.playbackRate = speed.clamp(0.25, 2.0);
  }

  @override
  void setPitchSemitones(int semitones) {
    _currentSemitones = semitones;
    if (_stNode != null) {
      _stNode!.pitchSemitones.value = semitones.toDouble();
    }
  }

  // --- Helpers --------------------------------------------------------------

  void _setState(AudioPlayerState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  // --- Dispose --------------------------------------------------------------

  @override
  Future<void> dispose() async {
    await _teardownGraph();
    _positionController.close();
    _durationController.close();
    _playingController.close();
    _stateController.close();
  }
}

/// Factory function for conditional import.
PlatformAudioPlayer createPlatformAudioPlayer() => WebAudioPlayer();
