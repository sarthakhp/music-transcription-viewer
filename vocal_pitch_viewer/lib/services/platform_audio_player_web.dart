import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'platform_audio_player.dart';

// ─── SoundTouchNode JS interop ──────────────────────────────────────────────

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

// ─── Shared AudioContext ────────────────────────────────────────────────────

/// Shared AudioContext across all WebAudioPlayer instances.
/// Created lazily on first use, resumed on user gesture.
web.AudioContext? _sharedContext;
bool _workletRegistered = false;

Future<web.AudioContext> _getOrCreateContext() async {
  if (_sharedContext != null) return _sharedContext!;
  _sharedContext = web.AudioContext();
  debugPrint('[WebAudio] AudioContext created, state=${_sharedContext!.state}');
  return _sharedContext!;
}

Future<void> _ensureWorkletRegistered(web.AudioContext ctx) async {
  if (_workletRegistered) return;
  if (_soundTouchNodeClass == null) {
    debugPrint('[WebAudio] SoundTouchNode not available on globalThis');
    return;
  }
  try {
    await SoundTouchNodeJS.register(ctx, '/soundtouch-processor.js').toDart;
    _workletRegistered = true;
    debugPrint('[WebAudio] SoundTouch worklet registered');
  } catch (e) {
    debugPrint('[WebAudio] Worklet registration failed: $e');
  }
}

// ─── WebAudioPlayer ─────────────────────────────────────────────────────────

class WebAudioPlayer implements PlatformAudioPlayer {
  web.HTMLAudioElement? _audio;
  web.AudioContext? _ctx;
  web.MediaElementAudioSourceNode? _source;
  SoundTouchNodeJS? _stNode;
  String? _blobUrl;

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
    if (_audio == null) return Duration.zero;
    return Duration(milliseconds: (_audio!.currentTime * 1000).round());
  }

  @override
  Duration? get duration {
    if (_audio == null) return null;
    final d = _audio!.duration;
    if (d.isNaN || d.isInfinite) return null;
    return Duration(milliseconds: (d * 1000).round());
  }

  @override
  bool get playing => _isPlaying;

  @override
  AudioPlayerState get state => _state;

  // ─── Loading ──────────────────────────────────────────────────────────────

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

    // Create <audio> element.
    _audio = web.document.createElement('audio') as web.HTMLAudioElement;
    _audio!.preload = 'auto';
    // Append to DOM (detached audio elements have inconsistent behavior).
    web.document.body!.append(_audio!);

    // Set up event listeners BEFORE setting src.
    _setupEventListeners();

    _audio!.src = _blobUrl!;

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
    _audio!.addEventListener('canplay', onReady);
    _audio!.addEventListener('error', onErr);

    try {
      await readyCompleter.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[WebAudio] Audio load failed: $e');
      _setState(AudioPlayerState.idle);
      rethrow;
    } finally {
      _audio!.removeEventListener('canplay', onReady);
      _audio!.removeEventListener('error', onErr);
    }

    // Set up Web Audio graph.
    await _setupGraph();

    _setState(AudioPlayerState.ready);
    _durationController.add(duration);
    debugPrint('[WebAudio] Loaded, duration=${duration?.inSeconds}s');
  }

  // ─── Web Audio Graph ──────────────────────────────────────────────────────

  Future<void> _setupGraph() async {
    _ctx = await _getOrCreateContext();
    await _ensureWorkletRegistered(_ctx!);

    // createMediaElementSource can only be called once per element per context.
    _source = _ctx!.createMediaElementSource(_audio!);

    // Try to create SoundTouchNode for pitch shifting.
    if (_workletRegistered && _soundTouchNodeClass != null) {
      try {
        _stNode = SoundTouchNodeJS(_ctx!);
        _stNode!.pitchSemitones.value = _currentSemitones.toDouble();
        _source!.connect(_stNode!);
        _stNode!.connect(_ctx!.destination);
        debugPrint('[WebAudio] Graph: source → SoundTouchNode → destination');
      } catch (e) {
        debugPrint('[WebAudio] SoundTouchNode failed ($e), using passthrough');
        _stNode = null;
        _source!.connect(_ctx!.destination);
      }
    } else {
      _source!.connect(_ctx!.destination);
      debugPrint('[WebAudio] Graph: source → destination (no pitch shift)');
    }
  }

  Future<void> _teardownGraph() async {
    _removeEventListeners();
    _isPlaying = false;

    if (_audio != null) {
      _audio!.pause();
      _audio!.removeAttribute('src');
      _audio!.remove();
      _audio = null;
    }

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

  // ─── Event Listeners ──────────────────────────────────────────────────────

  void _setupEventListeners() {
    final audio = _audio!;

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

    _onError = ((web.Event _) {
      debugPrint('[WebAudio] Audio element error');
      _isPlaying = false;
      _playingController.add(false);
      _setState(AudioPlayerState.idle);
    }).toJS;

    audio.addEventListener('timeupdate', _onTimeUpdate!);
    audio.addEventListener('loadedmetadata', _onLoadedMetadata!);
    audio.addEventListener('canplay', _onCanPlay!);
    audio.addEventListener('ended', _onEnded!);
    audio.addEventListener('waiting', _onWaiting!);
    audio.addEventListener('playing', _onPlaying!);
    audio.addEventListener('pause', _onPause!);
    audio.addEventListener('error', _onError!);
  }

  void _removeEventListeners() {
    final audio = _audio;
    if (audio == null) return;

    if (_onTimeUpdate != null) audio.removeEventListener('timeupdate', _onTimeUpdate!);
    if (_onLoadedMetadata != null) audio.removeEventListener('loadedmetadata', _onLoadedMetadata!);
    if (_onCanPlay != null) audio.removeEventListener('canplay', _onCanPlay!);
    if (_onEnded != null) audio.removeEventListener('ended', _onEnded!);
    if (_onWaiting != null) audio.removeEventListener('waiting', _onWaiting!);
    if (_onPlaying != null) audio.removeEventListener('playing', _onPlaying!);
    if (_onPause != null) audio.removeEventListener('pause', _onPause!);
    if (_onError != null) audio.removeEventListener('error', _onError!);

    _onTimeUpdate = null;
    _onLoadedMetadata = null;
    _onCanPlay = null;
    _onEnded = null;
    _onWaiting = null;
    _onPlaying = null;
    _onPause = null;
    _onError = null;
  }

  // ─── Playback ─────────────────────────────────────────────────────────────

  @override
  Future<void> play() async {
    if (_audio == null) return;

    // Resume AudioContext if suspended (needs user gesture chain).
    if (_ctx != null && _ctx!.state == 'suspended') {
      await _ctx!.resume().toDart;
      debugPrint('[WebAudio] AudioContext resumed');
    }

    try {
      await _audio!.play().toDart;
    } catch (e) {
      debugPrint('[WebAudio] play() failed: $e');
    }
  }

  @override
  Future<void> pause() async {
    _audio?.pause();
  }

  @override
  Future<void> stop() async {
    if (_audio == null) return;
    _audio!.pause();
    _audio!.currentTime = 0;
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_audio == null) return;
    final wasCompleted = _state == AudioPlayerState.completed;
    _audio!.currentTime = position.inMilliseconds / 1000.0;
    _positionController.add(position);
    if (wasCompleted) {
      _setState(AudioPlayerState.ready);
      await play();
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_audio == null) return;
    _audio!.playbackRate = speed.clamp(0.5, 2.0);
  }

  @override
  void setPitchSemitones(int semitones) {
    _currentSemitones = semitones;
    if (_stNode != null) {
      _stNode!.pitchSemitones.value = semitones.toDouble();
      debugPrint('[WebAudio] Pitch set to $semitones semitones');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _setState(AudioPlayerState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

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
