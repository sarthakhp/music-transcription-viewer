part of 'home_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _HomeScreenAudio on _HomeScreenState {
  /// Switch to a different audio track instantly using pre-loaded players
  Future<void> _switchTrack(AudioTrackType newTrack) async {
    if (newTrack == _currentTrack) return;
    if (!_audioService.isTrackLoaded(newTrack)) return;
    if (_isSwitchingTrack) return;

    setState(() => _isSwitchingTrack = true);

    try {
      final success = await _audioService.switchToTrack(newTrack);

      if (mounted) {
        setState(() {
          if (success) _currentTrack = newTrack;
          _isSwitchingTrack = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSwitchingTrack = false);
      }
    }
  }

  Future<void> _loadAudio(AppState appState) async {
    if (appState.audioBytes == null || _audioLoaded) {
      debugPrint('⏭️ Skipping _loadAudio: audioBytes=${appState.audioBytes != null}, _audioLoaded=$_audioLoaded');
      return;
    }

    debugPrint('🎵 Starting _loadAudio');
    setState(() => _isLoadingAudio = true);
    appState.setPreparingAudio(true);

    final mimeType = _getMimeType(appState.audioFileName ?? '');
    debugPrint('🎵 MIME type: $mimeType');

    bool success = false;

    if (appState.originalAudio != null) {
      debugPrint('🎵 Loading original audio (${appState.originalAudio!.length} bytes)');
      final result = await _audioService.loadTrack(
        AudioTrackType.original,
        appState.originalAudio!,
        'audio/mpeg',
        setActive: true,
      );
      debugPrint('🎵 Original audio load result: $result');
      success = result;
    }

    if (appState.vocalsAudio != null) {
      debugPrint('🎵 Loading vocals audio (${appState.vocalsAudio!.length} bytes)');
      final result = await _audioService.loadTrack(
        AudioTrackType.vocal,
        appState.vocalsAudio!,
        'audio/mpeg',
        setActive: !success,
      );
      debugPrint('🎵 Vocals audio load result: $result');
      if (!success) success = result;
    }

    if (appState.instrumentalAudio != null) {
      debugPrint('🎵 Loading instrumental audio (${appState.instrumentalAudio!.length} bytes)');
      final result = await _audioService.loadTrack(
        AudioTrackType.instrumental,
        appState.instrumentalAudio!,
        'audio/mpeg',
        setActive: false,
      );
      debugPrint('🎵 Instrumental audio load result: $result');
    }

    if (!success) {
      debugPrint('🎵 Loading fallback audio from audioBytes (${appState.audioBytes!.length} bytes)');
      success = await _audioService.loadFromBytes(appState.audioBytes!, mimeType);
      debugPrint('🎵 Fallback audio load result: $success');
    }

    debugPrint('🎵 Audio loading complete. Success: $success');

    if (success && mounted) {
      debugPrint('✅ Setting audio as loaded and clearing preparing flag');
      setState(() {
        _audioLoaded = true;
        _isLoadingAudio = false;
      });
      appState.setPreparingAudio(false);

      // Apply current settings to the audio engine so persisted
      // values (speed, transpose) take effect immediately.
      _audioService.setSpeed(_playbackSpeed);
      _audioService.setPitchSemitones(_transposeAmount);

      // Cancel any previous subscriptions before creating new ones
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _playingSubscription?.cancel();
      _processingStateSubscription?.cancel();

      _positionSubscription = _audioService.positionStream.listen((position) {
        if (!mounted) return;
        final time = position.inMilliseconds / 1000.0;
        final timerRunning = _playheadAnimationTimer != null && _lastPositionUpdateTime != null;

        if (timerRunning) {
          _lastStreamPosition = time;
          final elapsed = DateTime.now().difference(_lastPositionUpdateTime!);
          final interpolated = _lastKnownPosition + elapsed.inMilliseconds / 1000.0 * _playbackSpeed;
          final diff = time - interpolated;

          if (_awaitingFirstStreamSync) {
            // First stream event after pressing play: always snap to stream.
            // On web, the audio engine may start from a keyframe slightly before the
            // seeked position, so the stream position is the ground truth here.
            final correction = time - _lastKnownPosition;
            debugPrint('[FirstSync] seeded=$_lastKnownPosition → stream=$time  correction=${correction.toStringAsFixed(3)}s');
            _awaitingFirstStreamSync = false;
            _lastKnownPosition = time;
          } else if (diff.abs() > 1.0) {
            // Large jump = seek; snap directly to stream position
            _lastKnownPosition = time;
          } else {
            // Normal playback: advance baseline to max(stream, interpolated) to prevent
            // backward visual jumps while still resyncing every ~200ms to avoid timer drift.
            _lastKnownPosition = interpolated > time ? interpolated : time;
          }
          _lastPositionUpdateTime = DateTime.now();
        } else {
          // Paused — stream is authoritative
          _lastStreamPosition = time;
          _lastKnownPosition = time;
          _lastPositionUpdateTime = DateTime.now();
          appState.setCurrentTime(time);
          _viewState.updateViewWindowForPlayback(time, appState.pitchData?.maxTime ?? 120);
        }
      });

      _durationSubscription = _audioService.durationStream.listen((duration) {
        if (mounted && duration != null) {
          appState.setDuration(duration.inMilliseconds / 1000.0);
        }
      });

      _playingSubscription = _audioService.playingStream.listen((playing) {
        if (mounted) {
          appState.setPlaying(playing);
          if (playing) {
            _startPlayheadAnimation();
          } else {
            _stopPlayheadAnimation();
          }
        }
      });

      _processingStateSubscription = _audioService.stateStream.listen((state) {
        if (!mounted) return;
        debugPrint('[AudioPlayerState] $state  waitingForBuffer=$_waitingForBuffer');
        if (state == AudioPlayerState.ready && _waitingForBuffer) {
          _waitingForBuffer = false;
          final actualPos = _audioService.position.inMilliseconds / 1000.0;
          debugPrint('[BufferReady] Reseeding from actual pos=$actualPos');
          _lastKnownPosition = actualPos;
          _lastPositionUpdateTime = DateTime.now();
          _awaitingFirstStreamSync = true;
        }
      });
    }
  }

  /// Download audio stems for a job
  Future<void> _downloadAudioStems(String jobId, String? inputFilename) async {
    final appState = context.read<AppState>();

    try {
      appState.setPreparingAudio(true);

      final results = await Future.wait([
        _apiService.downloadStem(jobId: jobId, stemName: 'original'),
        _apiService.downloadStem(jobId: jobId, stemName: 'vocals'),
        _apiService.downloadStem(jobId: jobId, stemName: 'instrumental'),
      ]);

      appState.setAllAudioStems(
        original: results[0].isSuccess ? results[0].data : null,
        vocals: results[1].isSuccess ? results[1].data : null,
        instrumental: results[2].isSuccess ? results[2].data : null,
      );

      if (results[1].isSuccess && results[1].data != null) {
        appState.setAudioData(results[1].data!, inputFilename ?? 'vocals.mp3');
      } else if (results[0].isSuccess && results[0].data != null) {
        appState.setAudioData(results[0].data!, inputFilename ?? 'original.mp3');
      }
    } catch (e) {
      debugPrint('Error downloading audio stems: $e');
      appState.setError('Failed to download audio: ${e.toString()}');
      appState.setPreparingAudio(false);
    }
  }

  /// Start smooth playhead animation at 60fps
  void _startPlayheadAnimation() {
    _playheadAnimationTimer?.cancel();

    // Seed baseline from actual audio position to avoid stale interpolation on resume.
    // Also arm the first-sync flag so the first positionStream event corrects any
    // keyframe-snap offset introduced by the web audio engine after a seek.
    final audioPos = _audioService.position.inMilliseconds / 1000.0;
    final appState = context.read<AppState>();
    debugPrint('[StartAnim] audioPos=$audioPos, appCurrentTime=${appState.currentTime}, prev_lastKnown=$_lastKnownPosition');
    _lastKnownPosition = audioPos;
    _lastPositionUpdateTime = DateTime.now();
    _awaitingFirstStreamSync = true;
    _timerTickCount = 0;

    // Arm _waitingForBuffer regardless of current processingState — buffering may fire
    // either before or after this point (race with the audio engine). The listener will
    // clear it when ready fires.
    _waitingForBuffer = true;
    final currentState = _audioService.playerState;
    debugPrint('[StartAnim] seed=$audioPos  firstSync=ARMED  playerState=$currentState  waitingForBuffer=$_waitingForBuffer');

    _playheadAnimationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || !appState.isPlaying) {
        _stopPlayheadAnimation();
        return;
      }

      if (_lastPositionUpdateTime != null) {
        final elapsed = DateTime.now().difference(_lastPositionUpdateTime!);
        final interpolatedPosition = _lastKnownPosition + elapsed.inMilliseconds / 1000.0 * _playbackSpeed;
        appState.setCurrentTime(interpolatedPosition);
        _viewState.updateViewWindowForPlayback(interpolatedPosition, appState.pitchData?.maxTime ?? 120);

        // Log display vs last-known stream position every ~1 second (60 ticks)
        _timerTickCount++;
        if (_timerTickCount % 60 == 0) {
          final gap = interpolatedPosition - _lastStreamPosition;
          debugPrint('[Timer] display=${interpolatedPosition.toStringAsFixed(3)}  lastStream=${_lastStreamPosition.toStringAsFixed(3)}  gap=${gap.toStringAsFixed(3)}s');
        }
      }
    });
  }

  /// Stop smooth playhead animation
  void _stopPlayheadAnimation() {
    _playheadAnimationTimer?.cancel();
    _playheadAnimationTimer = null;
  }

  String _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/mp4';
      case 'flac':
        return 'audio/flac';
      case 'webm':
        return 'audio/webm';
      default:
        return 'audio/mpeg';
    }
  }
}
