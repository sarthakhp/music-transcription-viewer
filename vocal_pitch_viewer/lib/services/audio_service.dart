import 'dart:async';
import 'package:flutter/foundation.dart';
import 'platform_audio_player.dart';
import 'platform_audio_player.dart'
    if (dart.library.io) 'platform_audio_player_native.dart'
    if (dart.library.js_interop) 'platform_audio_player_web.dart'
    as platform;

export 'platform_audio_player.dart' show AudioPlayerState;

enum AudioTrackType {
  original,
  vocal,
  instrumental,
}

/// Audio playback service with multi-track support.
///
/// On native (mobile/desktop): uses just_audio via [NativeAudioPlayer].
/// On web: uses HTMLAudioElement + SoundTouchNode via [WebAudioPlayer].
class AudioService {
  final Map<AudioTrackType, PlatformAudioPlayer> _players = {};
  AudioTrackType _activeTrack = AudioTrackType.original;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _stateController = StreamController<AudioPlayerState>.broadcast();

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<AudioPlayerState>? _stateSubscription;

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<AudioPlayerState> get stateStream => _stateController.stream;

  PlatformAudioPlayer? get _player => _players[_activeTrack];

  bool get isPlaying {
    final player = _player;
    if (player == null) return false;
    return player.playing && player.state != AudioPlayerState.completed;
  }

  Duration get position => _player?.position ?? Duration.zero;
  Duration? get duration => _player?.duration;
  AudioPlayerState get playerState =>
      _player?.state ?? AudioPlayerState.idle;
  AudioTrackType get activeTrack => _activeTrack;

  // ─── Loading ──────────────────────────────────────────────────────────────

  Future<bool> loadFromBytes(Uint8List bytes, String mimeType) =>
      loadTrack(AudioTrackType.original, bytes, mimeType, setActive: true);

  Future<bool> loadTrack(
    AudioTrackType trackType,
    Uint8List bytes,
    String mimeType, {
    bool setActive = false,
    void Function(String status)? onStatusUpdate,
  }) async {
    try {
      debugPrint('Loading track $trackType (${bytes.length} bytes, $mimeType)');

      // Dispose old player for this track.
      await _players[trackType]?.dispose();

      // Create platform-appropriate player.
      final player = platform.createPlatformAudioPlayer();
      _players[trackType] = player;

      onStatusUpdate?.call('Preparing audio...');
      await player.load(bytes, mimeType);

      debugPrint('Loaded $trackType');

      if (setActive) {
        _activeTrack = trackType;
        _setupListeners(player);
        debugPrint('Active track -> $trackType');
      }
      return true;
    } catch (e, st) {
      debugPrint('Error loading $trackType: $e\n$st');
      return false;
    }
  }

  // ─── Listeners ────────────────────────────────────────────────────────────

  void _setupListeners(PlatformAudioPlayer player) {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _stateSubscription?.cancel();

    _positionSubscription =
        player.positionStream.listen(_positionController.add);
    _durationSubscription =
        player.durationStream.listen(_durationController.add);
    _playingSubscription =
        player.playingStream.listen(_playingController.add);
    _stateSubscription = player.stateStream.listen(_stateController.add);
  }

  // ─── Playback ─────────────────────────────────────────────────────────────

  Future<void> play() async {
    await _player?.play();
  }

  Future<void> pause() async {
    await _player?.pause();
  }

  Future<void> togglePlayPause() async {
    if (_player == null) return;
    final isCompleted = _player!.state == AudioPlayerState.completed;
    if (_player!.playing && !isCompleted) {
      await pause();
    } else {
      if (isCompleted) {
        final dur = _player!.duration;
        if (dur != null && _player!.position >= dur) {
          await _player!.seek(Duration.zero);
        }
      }
      await play();
    }
  }

  Future<void> stop() async {
    await _player?.stop();
  }

  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  Future<void> seekToSeconds(double seconds) =>
      seek(Duration(milliseconds: (seconds * 1000).round()));

  double _currentSpeed = 1.0;
  double get speed => _currentSpeed;

  Future<void> setSpeed(double speed) async {
    _currentSpeed = speed.clamp(0.5, 2.0);
    await _player?.setSpeed(_currentSpeed);
  }

  /// Sets pitch shift in semitones (-12 to +12). Speed is preserved.
  /// On web, this drives the SoundTouchNode. On native, currently a no-op.
  void setPitchSemitones(int semitones) {
    for (final player in _players.values) {
      player.setPitchSemitones(semitones);
    }
  }

  // ─── Track switching ──────────────────────────────────────────────────────

  Future<bool> switchToTrack(AudioTrackType trackType) async {
    if (!_players.containsKey(trackType)) return false;
    if (_activeTrack == trackType) return true;

    final currentPlayer = _players[_activeTrack];
    final targetPlayer = _players[trackType];
    if (targetPlayer == null) return false;

    final wasPlaying = currentPlayer?.playing ?? false;
    final currentPosition = currentPlayer?.position ?? Duration.zero;

    try {
      await currentPlayer?.pause();
      await targetPlayer.seek(currentPosition);
      await targetPlayer.setSpeed(_currentSpeed);
      _activeTrack = trackType;
      _setupListeners(targetPlayer);
      if (wasPlaying) targetPlayer.play();
      _durationController.add(targetPlayer.duration);
      _positionController.add(currentPosition);
      _playingController.add(wasPlaying);
      return true;
    } catch (e) {
      debugPrint('Error switching to $trackType: $e');
      return false;
    }
  }

  bool isTrackLoaded(AudioTrackType trackType) =>
      _players.containsKey(trackType);

  // ─── Dispose ──────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _stateSubscription?.cancel();
    _stateController.close();

    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
