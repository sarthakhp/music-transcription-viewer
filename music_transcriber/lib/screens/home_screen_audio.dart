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
        // When paused/stopped the Ticker is not running, so we update position
        // here (e.g. after a seek while paused). During playback the Ticker
        // reads media.currentTime directly each frame — no correction needed.
        if (_playheadTicker == null || !_playheadTicker!.isActive) {
          final time = position.inMilliseconds / 1000.0;
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
        if (state == AudioPlayerState.buffering) {
          // Audio stalled — freeze Ticker so playhead doesn't race ahead.
          _waitingForBuffer = true;
        } else if (state == AudioPlayerState.ready && _waitingForBuffer) {
          // Buffer recovered — Ticker will pick up live currentTime next frame.
          _waitingForBuffer = false;
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

  /// Start vsync-synced playhead — reads media.currentTime directly each frame.
  /// No dead-reckoning, no correction jumps.
  void _startPlayheadAnimation() {
    _playheadTicker?.dispose();
    _waitingForBuffer = false;
    final appState = context.read<AppState>();

    _playheadTicker = createTicker((_) {
      if (!mounted || !appState.isPlaying) {
        _stopPlayheadAnimation();
        return;
      }
      if (_waitingForBuffer) return;

      final pos = _audioService.position.inMilliseconds / 1000.0;
      appState.setCurrentTime(pos);
      _viewState.updateViewWindowForPlayback(pos, appState.pitchData?.maxTime ?? 120);
    });
    _playheadTicker!.start();
  }

  /// Stop playhead ticker.
  void _stopPlayheadAnimation() {
    _playheadTicker?.dispose();
    _playheadTicker = null;
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
