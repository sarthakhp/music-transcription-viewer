part of 'home_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _HomeScreenJobs on _HomeScreenState {
  /// Load completed and failed jobs from API.
  ///
  /// Failed jobs are surfaced separately so the user can retry them without
  /// re-uploading the file / re-entering the URL.
  Future<void> _loadCompletedJobs() async {
    setState(() => _isLoadingJobs = true);

    try {
      final results = await Future.wait([
        _apiService.listJobs(status: 'completed'),
        _apiService.listJobs(status: 'failed'),
      ]);

      final completedResponse = results[0];
      final failedResponse = results[1];

      setState(() {
        if (completedResponse.isSuccess && completedResponse.data != null) {
          _completedJobs = completedResponse.data!.jobs;
        } else {
          debugPrint('Failed to load completed jobs: ${completedResponse.error}');
        }
        if (failedResponse.isSuccess && failedResponse.data != null) {
          _failedJobs = failedResponse.data!.jobs;
        } else {
          debugPrint('Failed to load failed jobs: ${failedResponse.error}');
        }
        _isLoadingJobs = false;
      });
    } catch (e) {
      setState(() => _isLoadingJobs = false);
      debugPrint('Error loading jobs: $e');
    }
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

  /// Handle job selection — load job data and display
  Future<void> _onJobSelected(String jobId) async {
    final appState = context.read<AppState>();

    try {
      appState.setLoading(true);
      appState.setError(null);

      final resultsResponse = await _apiService.getJobResults(jobId);
      String? inputFilename;
      if (resultsResponse.isSuccess && resultsResponse.data != null) {
        inputFilename = resultsResponse.data!.inputFilename;
      }

      final results = await _apiService.getAllProcessedData(jobId);

      if (results.frames.isSuccess && results.frames.data != null) {
        appState.setPitchData(results.frames.data!);
      }

      if (results.chords.isSuccess && results.chords.data != null) {
        appState.setChordData(results.chords.data!);
      }

      await Future.wait([
        _downloadAudioStems(jobId, inputFilename),
        _fetchInstrumentData(jobId),
      ]);

      appState.setLoading(false);
      // Remember this job so a page reload reopens it instead of dropping
      // back to the home screen.
      _userSettings.saveLastJobId(jobId);

      // Set current job ID for auto-save tracking
      _currentJobId = jobId;

      // Restore saved settings for this job
      _restoreJobSettings(jobId);
    } catch (e) {
      appState.setError('Failed to load job data: ${e.toString()}');
      appState.setLoading(false);
    }
  }

  /// Restore saved settings for a job (view state, playback settings)
  void _restoreJobSettings(String jobId) {
    final settings = _userSettings.loadJobSettings(jobId);

    setState(() {
      _playbackSpeed = settings.playbackSpeed;
      _transposeAmount = settings.transposeAmount;
      _sargamEnabled = settings.sargamEnabled;
      _scaleRoot = settings.scaleRoot;
    });

    // Apply to view state
    _viewState.applyViewSettings(settings);

    // Apply to audio service
    _audioService.setSpeed(settings.playbackSpeed);
    _audioService.setPitchSemitones(settings.transposeAmount);
  }

  /// Reopen the job that was in the viewer before a page reload. Runs once
  /// at startup when a persisted job id exists. If the job can no longer be
  /// loaded (deleted, server unreachable, etc.), silently clears the stale
  /// pointer and falls back to the home screen instead of surfacing an error
  /// for something the user didn't just click.
  Future<void> _restoreLastJob(String jobId) async {
    await _onJobSelected(jobId);

    if (!mounted) return;
    final appState = context.read<AppState>();
    if (!appState.isReady) {
      _userSettings.saveLastJobId(null);
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
      debugPrint('Instrument data not available for job $jobId: $e');
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
  Future<void> _submitUrlForTranscription(String url, {double? startTime, double? endTime}) async {
    final appState = context.read<AppState>();

    appState.startUpload();

    try {
      final response = await _apiService.transcribeUrl(
        url: url,
        startTime: startTime,
        endTime: endTime,
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
  Future<void> _uploadAudioBytes(Uint8List bytes, String fileName) async {
    if (!mounted) return;
    final jobId = await _uploadService.uploadAudioFile(
      fileBytes: bytes,
      fileName: fileName,
    );
    if (jobId != null && mounted) {
      _pollingService.startPolling(jobId);
    }
  }
}
