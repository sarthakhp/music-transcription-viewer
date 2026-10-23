part of 'home_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _HomeScreenJobs on _HomeScreenState {
  /// Load completed and failed jobs from API.
  ///
  /// Failed jobs are surfaced separately so the user can retry them without
  /// re-uploading the file / re-entering the URL.
  ///
  /// The list shows the on-device copy first when one exists; [fresh] waits for
  /// the latest from the network. The loading card only shows on the very
  /// first load, so a background refresh never blanks a list you're reading.
  Future<void> _loadCompletedJobs({bool fresh = false}) async {
    if (_completedJobs.isEmpty) setState(() => _isLoadingJobs = true);

    try {
      final results = await Future.wait([
        _apiService.listJobs(status: 'completed', fresh: fresh),
        _apiService.listJobs(status: 'failed'),
      ]);

      final completedResponse = results[0];
      final failedResponse = results[1];

      setState(() {
        if (completedResponse.isSuccess && completedResponse.data != null) {
          _completedJobs = _withCloudJobs(completedResponse.data!.jobs);
        } else {
        }
        if (failedResponse.isSuccess && failedResponse.data != null) {
          _failedJobs = failedResponse.data!.jobs;
        } else {
        }
        _isLoadingJobs = false;
      });
      _refreshCloudJobs();
    } catch (e) {
      setState(() => _isLoadingJobs = false);
    }
  }

  /// Merge the local job list with the cloud listing: local jobs are tagged
  /// synced or device-only, and cloud jobs not on this device are appended.
  /// Without a reachable cloud the list is returned untouched (no badges).
  List<JobListItem> _withCloudJobs(List<JobListItem> local) {
    if (!_cloudAvailable) return local;
    final cloudIds = {for (final job in _cloudJobs) job.id};
    final localIds = {for (final job in local) job.id};
    final merged = [
      for (final job in local)
        job.withStorage(
          cloudIds.contains(job.id) ? JobStorage.synced : JobStorage.deviceOnly,
        ),
      for (final job in _cloudJobs)
        if (!localIds.contains(job.id)) job.withStorage(JobStorage.cloudOnly),
    ];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  /// Fetch the cloud listing in the background, so the local list shows
  /// immediately and cloud-only jobs fill in once it arrives.
  Future<void> _refreshCloudJobs() async {
    if (ApiConfig.isRemote) return;
    try {
      final response = await _apiService.listCloudJobs();
      if (!mounted) return;
      final data = response.data;
      if (!response.isSuccess || data == null || !data.available) return;
      setState(() {
        _cloudJobs = data.jobs;
        _cloudAvailable = true;
        _completedJobs = _withCloudJobs(
          _completedJobs.where((j) => j.storage != JobStorage.cloudOnly).toList(),
        );
      });
    } catch (_) {
      // The cloud is optional: keep showing the local list.
    }
  }

  /// Download a cloud-only job onto this device. Returns false (and shows an
  /// error) if it couldn't be fetched.
  Future<bool> _importCloudJob(String jobId) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Downloading from cloud...'),
      behavior: SnackBarBehavior.floating,
    ));
    final response = await _apiService.importCloudJob(jobId);
    if (!mounted) return false;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (!response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response.error ?? 'Could not download from cloud'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return false;
    }
    setState(() {
      _completedJobs = [
        for (final job in _completedJobs)
          job.id == jobId ? job.withStorage(JobStorage.synced) : job,
      ];
    });
    return true;
  }

  /// Retry a failed job. Reuses audio already on the server (no re-download).
  Future<void> _onJobRetry(String jobId) async {
    final appState = context.read<AppState>();

    try {
      final response = await _apiService.retryJob(jobId);

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        // Move the job out of the failed list and into active processing.
        setState(() {
          _failedJobs.removeWhere((job) => job.id == jobId);
        });
        appState.completeUpload(jobId);
        _pollingService.startPolling(jobId);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response.data!.message),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to retry job: ${response.error ?? "Unknown error"}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to retry job. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Asks how to process a finished song again, then queues it as a new song.
  Future<void> _onReprocess(JobListItem job) async {
    final choice = await showReprocessSheet(context, job);
    if (choice == null || !mounted) return;

    final label = '${job.displayName} (${choice.audioType.label})';
    try {
      if (ApiConfig.isRemote) {
        await UploadQueue.instance.reprocess(
          sourceJobId: job.id,
          label: label,
          audioType: choice.audioType,
          instruments: choice.instruments,
        );
        _showReprocessMessage('Queued "$label". Follow it in the upload list.');
        return;
      }
      final response = await _apiService.reprocessJob(
        job.id,
        audioType: choice.audioType,
        instruments: choice.instruments,
      );
      if (!mounted) return;
      if (response.isSuccess && response.data != null) {
        _pollingService.startPolling(response.data!.jobId);
        _showReprocessMessage('Processing "$label" as a new song.');
      } else {
        _showReprocessMessage(
          "Couldn't process it again: ${response.error ?? 'the server gave no reason'}",
          isError: true,
        );
      }
    } catch (e) {
      final friendly = explainError(e, during: 'process this song again');
      _showReprocessMessage(friendly.message, isError: true);
    }
  }

  void _showReprocessMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Handle job selection — load job data and display
  Future<void> _onJobSelected(String jobId) async {
    final appState = context.read<AppState>();

    try {
      appState.setLoading(true);
      appState.setError(null);

      final isCloudOnly = _completedJobs.any(
        (job) => job.id == jobId && job.storage == JobStorage.cloudOnly,
      );
      if (isCloudOnly && !await _importCloudJob(jobId)) {
        appState.setLoading(false);
        return;
      }

      final resultsResponse = await _apiService.getJobResults(jobId);
      String? inputFilename;
      if (resultsResponse.isSuccess && resultsResponse.data != null) {
        appState.setAudioType(resultsResponse.data!.audioType);
        // Prefer user-set display_name over the original input filename.
        inputFilename = resultsResponse.data!.userDisplayName
            ?? resultsResponse.data!.videoTitle
            ?? resultsResponse.data!.inputFilename;
      }

      final results = await _apiService.getAllProcessedData(jobId);

      if (results.frames.isSuccess && results.frames.data != null) {
        // Music only songs have no voice frames, so give the viewer the stored length.
        results.frames.data!.declaredDuration = resultsResponse.data?.duration ?? 0;
        appState.setPitchData(results.frames.data!);
      }

      if (results.chords.isSuccess && results.chords.data != null) {
        appState.setChordData(results.chords.data!);
      }

      await Future.wait([
        _prepareAudioForJob(jobId, inputFilename),
        _fetchInstrumentData(jobId),
      ]);

      appState.setLoading(false);

      // Set current job ID for auto-save tracking
      _currentJobId = jobId;

      // Update URL so browser back/forward and direct links work.
      if (mounted) context.go('/jobs/$jobId');

      // Restore saved settings for this job
      _restoreJobSettings(jobId);
    } catch (e) {
      appState.setError('Failed to load job data: ${e.toString()}');
      appState.setLoading(false);
    }
  }

  /// Restore saved settings for a job (view state, playback settings).
  ///
  /// The local copy is applied immediately, so opening a song never waits on
  /// the network. A newer cloud copy (from another device) is fetched in the
  /// background and applied on top when it arrives.
  void _restoreJobSettings(String jobId) {
    final settings = _userSettings.loadJobSettings(jobId);
    _applyJobSettings(settings);
    _syncJobSettingsWithCloud(jobId, hadLocal: _userSettings.hasJobSettings(jobId));
  }

  /// Apply [settings] to the UI, the player and the view.
  void _applyJobSettings(JobSettings settings) {
    final appState = context.read<AppState>();
    setState(() {
      _playbackSpeed = settings.playbackSpeed;
      _transposeAmount = settings.transposeAmount;
      _sargamEnabled = settings.sargamEnabled;
      _scaleRoot = settings.scaleRoot;
      _showVocals = settings.showVocals;
      _showBass = settings.showBass;
      _showOther = settings.showOther;
      _vocalsMinConfidence = settings.vocalsMinConfidence;
      _bassMinConfidence = settings.bassMinConfidence;
      _otherMinConfidence = settings.otherMinConfidence;
      // Songs without their own value fall back to the app-wide one.
      _vocalDetail = settings.vocalDetail ?? _userSettings.vocalDetail;
    });
    appState.setReferenceFrequency(
      settings.referenceFrequency ?? _userSettings.referenceFrequency,
    );
    _tanpura.setSemitones(settings.scaleRoot);
    appState.setBpmOverride(settings.bpmOverride > 0 ? settings.bpmOverride : null);
    _cycle.restore(
      enabled: settings.cycleEnabled,
      start: settings.cycleStart,
      end: settings.cycleEnd,
    );

    // Apply to view state
    _viewState.applyViewSettings(settings);

    // Apply to audio service
    _audioService.setSpeed(settings.playbackSpeed);
    _audioService.setPitchSemitones(settings.transposeAmount);

    // The restore itself isn't an edit: record what the UI now shows as the
    // saved state (the track switch below is async, so re-record after it).
    _rebaselineSettings(settings.updatedAtMs);
    final track = AudioTrackType.values.where((t) => t.name == settings.track);
    if (track.isNotEmpty) {
      _switchTrack(track.first, persist: false).then((_) {
        if (mounted) _rebaselineSettings(_lastSavedSettings?.updatedAtMs ?? settings.updatedAtMs);
      });
    }
  }

  /// Reconcile this song's settings with the cloud copy, never blocking the
  /// UI: whichever side changed last wins, and a song with local settings but
  /// nothing in the cloud uploads them so other devices get them too.
  Future<void> _syncJobSettingsWithCloud(String jobId, {required bool hadLocal}) async {
    final cloud = await _settingsSync.fetch(jobId);
    // The user may have moved on to another song while this was in flight.
    if (!mounted || _currentJobId != jobId) return;

    final local = _lastSavedSettings ?? const JobSettings();
    if (cloud == null) {
      if (hadLocal) {
        final stamped = local.copyWith(
          updatedAtMs: local.updatedAtMs > 0
              ? local.updatedAtMs
              : DateTime.now().millisecondsSinceEpoch,
        );
        _lastSavedSettings = stamped;
        _userSettings.saveJobSettings(jobId, stamped);
        _settingsSync.schedulePush(jobId, stamped);
      }
      return;
    }
    if (cloud.updatedAtMs <= local.updatedAtMs) return; // local is as new or newer

    _lastSavedSettings = cloud;
    _userSettings.saveJobSettings(jobId, cloud);
    _applyJobSettings(cloud);
  }

  /// Open the job referenced by the URL on startup (e.g. a direct link to
  /// `/jobs/:id`). If the job can no longer be loaded (deleted, server
  /// unreachable, etc.), silently falls back to the home screen instead of
  /// surfacing an error for something the user didn't just click.
  Future<void> _restoreLastJob(String jobId) async {
    await _onJobSelected(jobId);

    if (!mounted) return;
    final appState = context.read<AppState>();
    if (!appState.isReady) {
      appState.setError(null);
    }
  }

  /// Fetch instrument transcription — silently ignored if unavailable (404 / older jobs)
  Future<void> _fetchInstrumentData(String jobId) async {
    final appState = context.read<AppState>();
    try {
      final response = await _apiService.getInstruments(jobId);
      if (response.isSuccess && response.data != null) {
        appState.setInstrumentData(response.data);
      }
    } catch (e) {
    }
  }

  /// Handle job deletion
  Future<void> _onJobDeleted(String jobId) async {
    try {
      final response = await _apiService.deleteJob(jobId);

      if (response.isSuccess) {
        setState(() {
          _completedJobs.removeWhere((job) => job.id == jobId);
          _failedJobs.removeWhere((job) => job.id == jobId);
          // Deleting removes only the local copy; a cloud copy stays listed.
          _completedJobs = _withCloudJobs(
            _completedJobs.where((j) => j.storage != JobStorage.cloudOnly).toList(),
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Job deleted successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to delete job: ${response.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting job: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Cancel an in-progress or queued job
  Future<void> _cancelCurrentJob() async {
    final appState = context.read<AppState>();
    final jobId = appState.currentJobId;
    if (jobId == null) return;

    try {
      final response = await _apiService.cancelJob(jobId);

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        if (data.cancelled) {
          // Job was successfully cancelled
          _pollingService.stopPolling();
          appState.cancelJob();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Job cancelled.'),
            behavior: SnackBarBehavior.floating,
          ));
        } else {
          // Job completed before cancel landed — refresh state
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(data.message),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else if (response.statusCode == 400) {
        // Job already in terminal state
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Job already finished.'),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to cancel job: ${response.error ?? "Unknown error"}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to cancel job. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// Submit a URL for transcription
  Future<void> _submitUrlForTranscription(
    String url, {
    double? startTime,
    double? endTime,
    AudioContentType audioType = AudioContentType.mixed,
    List<String> instruments = const [],
  }) async {
    final appState = context.read<AppState>();

    appState.startUpload();

    try {
      final response = await _apiService.transcribeUrl(
        url: url,
        startTime: startTime,
        endTime: endTime,
        audioType: audioType,
        instruments: instruments,
      );

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final jobId = response.data!.jobId;
        appState.completeUpload(jobId);
        _pollingService.startPolling(jobId);
      } else {
        appState.failJob(response.error ?? 'Failed to submit URL');
      }
    } catch (e) {
      if (mounted) {
        appState.failJob('Failed to submit URL. Please check your connection.');
      }
    }
  }

  /// Upload audio bytes directly (used by file-with-trim and recording flows).
  Future<void> _uploadAudioBytes(
    Uint8List bytes,
    String fileName, {
    AudioContentType audioType = AudioContentType.mixed,
    List<String> instruments = const [],
  }) async {
    if (!mounted) return;
    final jobId = await _uploadService.uploadAudioFile(
      fileBytes: bytes,
      fileName: fileName,
      audioType: audioType,
      instruments: instruments,
    );
    if (jobId != null && mounted) {
      _pollingService.startPolling(jobId);
    }
  }
}
