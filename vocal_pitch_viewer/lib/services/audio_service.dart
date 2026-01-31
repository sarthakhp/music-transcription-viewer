import 'dart:async';
import 'dart:convert'; // For base64Encode on web
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Audio track type enum
enum AudioTrackType {
  original,
  vocal,
  instrumental,
}

/// Custom audio source that streams bytes directly without base64 encoding
/// This is much more efficient than using data URIs for large audio files
class BytesAudioSource extends StreamAudioSource {
  final Uint8List bytes;
  final String mimeType;

  BytesAudioSource(this.bytes, this.mimeType);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      start ??= 0;
      end ??= bytes.length;

      debugPrint('🎵 BytesAudioSource.request: start=$start, end=$end, total=${bytes.length}');

      return StreamAudioResponse(
        sourceLength: bytes.length,
        contentLength: end - start,
        offset: start,
        stream: Stream.value(bytes.sublist(start, end)),
        contentType: mimeType,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error in BytesAudioSource.request: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Audio playback service using just_audio with multi-track support
class AudioService {
  // Multiple players for instant track switching
  final Map<AudioTrackType, AudioPlayer> _players = {};
  AudioTrackType _activeTrack = AudioTrackType.original;

  // Stream controllers for state updates
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();

  // Subscriptions for the active player
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;

  // Streams
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;

  // Current state - from active player
  AudioPlayer? get _player => _players[_activeTrack];
  bool get isPlaying {
    final player = _player;
    if (player == null) return false;
    // When audio completes, just_audio keeps playing=true but processingState=completed
    // We should treat completed state as not playing
    return player.playing && player.processingState != ProcessingState.completed;
  }
  Duration get position => _player?.position ?? Duration.zero;
  Duration? get duration => _player?.duration;

  /// Initialize the audio player with bytes data (default track)
  Future<bool> loadFromBytes(Uint8List bytes, String mimeType) async {
    return loadTrack(AudioTrackType.original, bytes, mimeType, setActive: true);
  }

  /// Load a specific track into its own player
  /// [onStatusUpdate] is called with status messages during loading
  Future<bool> loadTrack(
    AudioTrackType trackType,
    Uint8List bytes,
    String mimeType, {
    bool setActive = false,
    void Function(String status)? onStatusUpdate,
  }) async {
    try {
      debugPrint('🎵 Loading track $trackType (${bytes.length} bytes, $mimeType)');

      // Dispose existing player for this track if any
      await _players[trackType]?.dispose();

      final player = AudioPlayer();
      _players[trackType] = player;

      // On web, StreamAudioSource converts to Data URI anyway, so we do it directly
      // On mobile/desktop, use StreamAudioSource for better performance
      if (kIsWeb) {
        // Web: Use base64 Data URI (what StreamAudioSource does internally anyway)
        onStatusUpdate?.call('Encoding audio data...');
        debugPrint('🎵 Encoding to base64 for web platform');
        final base64Data = await compute(_base64EncodeInIsolate, bytes);
        final dataUri = 'data:$mimeType;base64,$base64Data';

        onStatusUpdate?.call('Initializing player...');
        debugPrint('🎵 Setting URL for $trackType');
        await player.setUrl(dataUri);
      } else {
        // Mobile/Desktop: Use StreamAudioSource for efficient streaming
        onStatusUpdate?.call('Preparing audio data...');
        debugPrint('🎵 Creating BytesAudioSource for $trackType');
        final audioSource = BytesAudioSource(bytes, mimeType);

        onStatusUpdate?.call('Initializing player...');
        debugPrint('🎵 Setting audio source for $trackType');
        await player.setAudioSource(audioSource);
      }

      debugPrint('🎵 Successfully loaded track $trackType');

      // If this should be the active track, set up listeners
      if (setActive) {
        _activeTrack = trackType;
        _setupListeners(player);
        debugPrint('🎵 Set $trackType as active track');
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading track $trackType: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Set up stream listeners for a player
  void _setupListeners(AudioPlayer player) {
    // Cancel existing subscriptions
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _processingStateSubscription?.cancel();

    _positionSubscription = player.positionStream.listen((position) {
      _positionController.add(position);
    });

    _durationSubscription = player.durationStream.listen((duration) {
      _durationController.add(duration);
    });

    _playingSubscription = player.playingStream.listen((playing) {
      _playingController.add(playing);
    });

    // Listen to processing state to handle completion
    _processingStateSubscription = player.processingStateStream.listen((state) {
      // When audio completes, pause it so the UI reflects the correct state
      if (state == ProcessingState.completed) {
        player.pause();
      }
    });
  }

  /// Play audio
  Future<void> play() async {
    await _player?.play();
  }
  
  /// Pause audio
  Future<void> pause() async {
    await _player?.pause();
  }
  
  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player == null) return;

    // Check if audio has completed (at the end)
    final isCompleted = _player!.processingState == ProcessingState.completed;

    if (_player!.playing && !isCompleted) {
      // Currently playing and not completed - pause it
      await pause();
    } else {
      // Not playing or completed - play it
      // If completed and at the end, seek to beginning first
      if (isCompleted) {
        final dur = _player!.duration;
        final pos = _player!.position;
        if (dur != null && pos >= dur) {
          await _player!.seek(Duration.zero);
        }
      }
      await play();
    }
  }
  
  /// Stop audio and reset position
  Future<void> stop() async {
    await _player?.stop();
    await _player?.seek(Duration.zero);
  }
  
  /// Seek to position
  Future<void> seek(Duration position) async {
    if (_player == null) return;

    // Check if we're seeking from a completed state
    final wasCompleted = _player!.processingState == ProcessingState.completed;

    await _player!.seek(position);

    // If we were in completed state and paused, resume playback
    // This handles the case where audio finished and user seeks to middle
    if (wasCompleted && !_player!.playing) {
      await _player!.play();
    }
  }

  /// Seek to time in seconds
  Future<void> seekToSeconds(double seconds) async {
    await seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _player?.setSpeed(speed.clamp(0.5, 2.0));
  }

  /// Switch to a new audio source while preserving position and playback state
  /// Returns true if successful (legacy method - use switchToTrack for instant switching)
  Future<bool> switchSource(Uint8List bytes, String mimeType) async {
    if (_player == null) {
      debugPrint('Cannot switch source: player not initialized');
      return false;
    }

    // Save current state
    final wasPlaying = isPlaying;
    final currentPosition = position;

    try {
      // Stop current playback
      await _player!.pause();

      // Create audio source from bytes (no base64 encoding needed!)
      final audioSource = BytesAudioSource(bytes, mimeType);

      // Load new source
      await _player!.setAudioSource(audioSource);

      // Restore position
      await _player!.seek(currentPosition);

      // Resume playback if it was playing (don't await - let it play async)
      if (wasPlaying) {
        _player!.play();
      }

      return true;
    } catch (e) {
      debugPrint('Error switching audio source: $e');
      return false;
    }
  }

  /// Switch to a pre-loaded track instantly
  /// This is the fastest method - switches between already-loaded players
  Future<bool> switchToTrack(AudioTrackType trackType) async {
    if (!_players.containsKey(trackType)) {
      debugPrint('Track $trackType not loaded');
      return false;
    }

    if (_activeTrack == trackType) {
      return true; // Already on this track
    }

    final currentPlayer = _players[_activeTrack];
    final targetPlayer = _players[trackType];

    if (targetPlayer == null) {
      return false;
    }

    // Save current state
    final wasPlaying = currentPlayer?.playing ?? false;
    final currentPosition = currentPlayer?.position ?? Duration.zero;

    try {
      // Pause current player
      await currentPlayer?.pause();

      // Seek target player to same position
      await targetPlayer.seek(currentPosition);

      // Switch active track
      _activeTrack = trackType;

      // Set up listeners for new active player
      _setupListeners(targetPlayer);

      // Resume playback if it was playing
      if (wasPlaying) {
        targetPlayer.play();
      }

      // Emit current state from new player
      _durationController.add(targetPlayer.duration);
      _positionController.add(currentPosition);
      _playingController.add(wasPlaying);

      return true;
    } catch (e) {
      debugPrint('Error switching to track $trackType: $e');
      return false;
    }
  }

  /// Check if a track is loaded
  bool isTrackLoaded(AudioTrackType trackType) {
    return _players.containsKey(trackType);
  }

  /// Get the active track type
  AudioTrackType get activeTrack => _activeTrack;

  /// Dispose resources
  Future<void> dispose() async {
    // Cancel subscriptions
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _processingStateSubscription?.cancel();

    // Dispose all players
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

/// Top-level function for base64 encoding in isolate (web only)
/// This MUST be a top-level function to work with compute()
String _base64EncodeInIsolate(Uint8List bytes) {
  return base64Encode(bytes);
}
