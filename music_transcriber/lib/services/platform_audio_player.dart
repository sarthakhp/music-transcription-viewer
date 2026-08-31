import 'dart:async';
import 'dart:typed_data';

/// Platform-independent processing state for audio players.
/// Maps to just_audio's ProcessingState on native and HTMLAudioElement events on web.
enum AudioPlayerState {
  idle,
  loading,
  ready,
  buffering,
  completed,
}

/// Abstract interface for a single audio player.
///
/// On native (mobile/desktop): wraps just_audio's AudioPlayer.
/// On web: owns an HTMLAudioElement + optional SoundTouchNode Web Audio graph.
abstract class PlatformAudioPlayer {
  /// Position updates (roughly every 200-250ms).
  Stream<Duration> get positionStream;

  /// Duration updates (fires once after metadata loads, then on src change).
  Stream<Duration?> get durationStream;

  /// Playing state changes.
  Stream<bool> get playingStream;

  /// Processing state changes.
  Stream<AudioPlayerState> get stateStream;

  /// Current position.
  Duration get position;

  /// Current duration, null if not loaded.
  Duration? get duration;

  /// Whether currently playing.
  bool get playing;

  /// Current processing state.
  AudioPlayerState get state;

  /// Load audio from raw bytes.
  Future<void> load(Uint8List bytes, String mimeType);

  /// Start playback.
  Future<void> play();

  /// Pause playback.
  Future<void> pause();

  /// Stop playback and seek to start.
  Future<void> stop();

  /// Seek to a position.
  Future<void> seek(Duration position);

  /// Set playback speed (0.25 - 2.0).
  Future<void> setSpeed(double speed);

  /// Set pitch shift in semitones (-12 to +12). Speed is preserved.
  void setPitchSemitones(int semitones);

  /// Release resources.
  Future<void> dispose();
}

/// Factory function — implemented differently per platform via conditional import.
/// See [createPlatformAudioPlayer] in platform_audio_player_native.dart and _web.dart.
PlatformAudioPlayer createPlatformAudioPlayer() =>
    throw UnsupportedError('Cannot create PlatformAudioPlayer on this platform');
