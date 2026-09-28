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

  // ===========================================================================
  // Orchestrator — the only entry point for getting a job's audio into the
  // player. Single owner of AppState.isPreparingAudio: the try/finally below
  // guarantees the "Preparing audio files…" overlay clears no matter which
  // stage fails, throws, or is only partially successful.
  // ===========================================================================

  Future<void> _prepareAudioForJob(String jobId, String? inputFilename) async {
    if (!mounted) return;
    if (_audioLoaded) return; // already loaded — nothing left to do
    if (_preparingAudioForJobId == jobId) return; // already fetching this exact job

    _preparingAudioForJobId = jobId;
    final appState = context.read<AppState>();
    appState.setPreparingAudio(true);

    try {
      final stems = await _fetchStemsForJob(jobId);
      if (!mounted) return;

      // Store whatever downloaded successfully before deciding if it's
      // enough to play — a job with only an instrumental stem (main tracks
      // failed) should still keep that stem rather than lose it.
      appState.setAllAudioStems(
        original: stems.original,
        vocals: stems.vocals,
        instrumental: stems.instrumental,
      );

      final primaryBytes = stems.primaryBytes;
      if (primaryBytes == null) {
        appState.setError('Failed to download audio for this job.');
        return;
      }
      appState.setAudioData(primaryBytes, stems.primaryFileName(inputFilename));

      await _loadAudioIntoPlayer(appState);
    } finally {
      if (_preparingAudioForJobId == jobId) _preparingAudioForJobId = null;
      appState.setPreparingAudio(false);
    }
  }

  // ===========================================================================
  // Stage 1 — FETCH. Pure network I/O; no AppState/UI side effects, no
  // exceptions escape (a failed stem just comes back null on that field).
  // ===========================================================================

  Future<AudioStemsResult> _fetchStemsForJob(String jobId) {
    return fetchAudioStems(_apiService, jobId);
  }

  // ===========================================================================
  // Stage 2 — LOAD INTO PLAYER. Feeds the stems already stored in AppState
  // into the audio engine and wires up playback listeners. Assumes the
  // caller (_prepareAudioForJob) owns the "preparing" flag's lifecycle.
  // ===========================================================================

  Future<void> _loadAudioIntoPlayer(AppState appState) async {
    setState(() => _isLoadingAudio = true);

    bool success = false;
    try {
      if (appState.originalAudio != null) {
        success = await _audioService.loadTrack(
          AudioTrackType.original,
          appState.originalAudio!,
          'audio/mpeg',
          setActive: true,
        );
      }

      if (appState.vocalsAudio != null) {
        final result = await _audioService.loadTrack(
          AudioTrackType.vocal,
          appState.vocalsAudio!,
          'audio/mpeg',
          setActive: !success,
        );
        if (!success) success = result;
      }

      if (appState.instrumentalAudio != null) {
        await _audioService.loadTrack(
          AudioTrackType.instrumental,
          appState.instrumentalAudio!,
          'audio/mpeg',
          setActive: false,
        );
      }

      if (!success) {
        final mimeType = _getMimeType(appState.audioFileName ?? '');
        success = await _audioService.loadFromBytes(appState.audioBytes!, mimeType);
      }
    } catch (e) {
      debugPrint('❌ Loading audio into player threw: $e');
      success = false;
    }

    if (!mounted) return;

    if (!success) {
      setState(() => _isLoadingAudio = false);
      _showAudioLoadFailedSnackBar();
      return;
    }

    _onAudioReady(appState);
  }

  // ===========================================================================
  // Stage 3 — AFTER LOADING. Runs once, exactly when playback is actually
  // ready: applies persisted settings and starts the position/duration/
  // playing/buffering listeners.
  // ===========================================================================

  void _onAudioReady(AppState appState) {
    setState(() {
      _audioLoaded = true;
      _isLoadingAudio = false;
    });

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

  void _showAudioLoadFailedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Audio could not be loaded. Playback is unavailable.'),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Theme.of(context).colorScheme.onError,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
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
