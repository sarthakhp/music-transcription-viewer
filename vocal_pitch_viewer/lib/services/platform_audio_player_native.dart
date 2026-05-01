import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'platform_audio_player.dart';

/// Native implementation using just_audio.
class NativeAudioPlayer implements PlatformAudioPlayer {
  ja.AudioPlayer? _player;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _stateController = StreamController<AudioPlayerState>.broadcast();

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<bool>? _playSub;
  StreamSubscription<ja.ProcessingState>? _stateSub;

  @override
  Stream<Duration> get positionStream => _positionController.stream;
  @override
  Stream<Duration?> get durationStream => _durationController.stream;
  @override
  Stream<bool> get playingStream => _playingController.stream;
  @override
  Stream<AudioPlayerState> get stateStream => _stateController.stream;

  @override
  Duration get position => _player?.position ?? Duration.zero;
  @override
  Duration? get duration => _player?.duration;
  @override
  bool get playing =>
      _player != null &&
      _player!.playing &&
      _player!.processingState != ja.ProcessingState.completed;
  @override
  AudioPlayerState get state => _mapState(_player?.processingState);

  // ─── Loading ──────────────────────────────────────────────────────────────

  @override
  Future<void> load(Uint8List bytes, String mimeType) async {
    await _player?.dispose();
    _player = ja.AudioPlayer();
    _setupListeners();

    // ignore: experimental_member_use
    final source = _BytesAudioSource(bytes, mimeType);
    // ignore: experimental_member_use
    await _player!.setAudioSource(source);
  }

  // ─── Playback ─────────────────────────────────────────────────────────────

  @override
  Future<void> play() async => _player?.play();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> stop() async {
    await _player?.stop();
    await _player?.seek(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_player == null) return;
    final wasCompleted =
        _player!.processingState == ja.ProcessingState.completed;
    await _player!.seek(position);
    if (wasCompleted && !_player!.playing) await play();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player?.setSpeed(speed.clamp(0.5, 2.0));
  }

  @override
  void setPitchSemitones(int semitones) {
    // just_audio supports setPitch on Android only (ratio, not semitones).
    // For now, no-op on native. Could be wired up per-platform later.
  }

  // ─── Listeners ────────────────────────────────────────────────────────────

  void _setupListeners() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _stateSub?.cancel();

    final player = _player!;
    _posSub = player.positionStream.listen(_positionController.add);
    _durSub = player.durationStream.listen(_durationController.add);
    _playSub = player.playingStream.listen(_playingController.add);
    _stateSub = player.processingStateStream.listen((s) {
      _stateController.add(_mapState(s));
      if (s == ja.ProcessingState.completed) player.pause();
    });
  }

  static AudioPlayerState _mapState(ja.ProcessingState? s) {
    switch (s) {
      case ja.ProcessingState.idle:
        return AudioPlayerState.idle;
      case ja.ProcessingState.loading:
        return AudioPlayerState.loading;
      case ja.ProcessingState.buffering:
        return AudioPlayerState.buffering;
      case ja.ProcessingState.ready:
        return AudioPlayerState.ready;
      case ja.ProcessingState.completed:
        return AudioPlayerState.completed;
      case null:
        return AudioPlayerState.idle;
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _stateSub?.cancel();
    await _player?.dispose();
    _player = null;
  }
}

/// Streams raw bytes as an audio source (mobile/desktop only).
// ignore: experimental_member_use
class _BytesAudioSource extends ja.StreamAudioSource {
  final Uint8List bytes;
  final String mimeType;
  _BytesAudioSource(this.bytes, this.mimeType);

  @override
  // ignore: experimental_member_use
  Future<ja.StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    // ignore: experimental_member_use
    return ja.StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: mimeType,
    );
  }
}

/// Factory function for conditional import.
PlatformAudioPlayer createPlatformAudioPlayer() => NativeAudioPlayer();
