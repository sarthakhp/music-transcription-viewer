import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../providers/app_state.dart';
import 'transcription_api_service.dart';

/// Service for polling job status in the background
class JobPollingService {
  final TranscriptionApiService _apiService;
  final AppState _appState;
  
  Timer? _pollingTimer;
  bool _isPolling = false;
  String? _currentJobId;

  JobPollingService({
    required TranscriptionApiService apiService,
    required AppState appState,
  })  : _apiService = apiService,
        _appState = appState;

  /// Start polling for a job
  void startPolling(String jobId) {
    if (_isPolling && _currentJobId == jobId) {
      return; // Already polling this job
    }

    stopPolling(); // Stop any existing polling

    _currentJobId = jobId;
    _isPolling = true;

    // Start immediate poll
    _pollOnce();

    // Start periodic polling
    _pollingTimer = Timer.periodic(
      ApiConfig.pollingInterval,
      (_) => _pollOnce(),
    );
  }

  /// Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _currentJobId = null;
  }

  /// Pause polling (keeps state but stops timer)
  void pausePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }

  /// Resume polling
  void resumePolling() {
    if (_currentJobId != null && !_isPolling) {
      startPolling(_currentJobId!);
    }
  }

  /// Poll once
  Future<void> _pollOnce() async {
    if (_currentJobId == null) return;

    try {
      final response = await _apiService.getJobStatus(_currentJobId!);

      if (!response.isSuccess) {
        // Handle error
        _appState.setError(response.error ?? 'Failed to get job status');
        return;
      }

      if (response.data == null) {
        _appState.setError('Polling error: Received null data from server');
        debugPrint('Job status response data is null for job: $_currentJobId');
        return;
      }

      final status = response.data!;

      // Update app state
      _appState.updateJobState(
        jobId: _currentJobId!,
        status: status.status,
        stage: status.stage,
        progress: status.progress,
        message: status.message,
      );

      // Check if job is complete or failed
      if (status.isComplete) {
        _appState.completeJob();

        // Save job ID before stopping polling (which sets _currentJobId to null)
        final completedJobId = _currentJobId!;
        stopPolling();

        // Trigger data fetch
        _onJobComplete(completedJobId);
      } else if (status.hasFailed) {
        _appState.failJob(status.errorMessage ?? 'Job processing failed');
        stopPolling();
      }
    } catch (e, stackTrace) {
      debugPrint('Polling error: $e');
      debugPrint('Stack trace: $stackTrace');
      _appState.setError('Polling error: ${e.toString()}');
    }
  }

  /// Handle job completion - fetch all data
  Future<void> _onJobComplete(String jobId) async {
    try {
      _appState.setLoading(true);

      // Fetch job results summary to get input filename
      final resultsResponse = await _apiService.getJobResults(jobId);
      String? inputFilename;
      if (resultsResponse.isSuccess && resultsResponse.data != null) {
        inputFilename = resultsResponse.data!.inputFilename;
      }

      // Fetch frames and chords in parallel
      final results = await _apiService.getAllProcessedData(jobId);

      // Update app state with data
      if (results.frames.isSuccess && results.frames.data != null) {
        _appState.setPitchData(results.frames.data!);
      } else {
        _appState.setError('Failed to fetch pitch data: ${results.frames.error ?? "No data available"}');
      }

      if (results.chords.isSuccess && results.chords.data != null) {
        _appState.setChordData(results.chords.data!);
      } else {
        _appState.setError('Failed to fetch chord data: ${results.chords.error ?? "No data available"}');
      }

      // Download audio stems (original, vocals, instrumental)
      await _downloadAudioStems(jobId, inputFilename);

      _appState.setLoading(false);
    } catch (e) {
      _appState.setError('Failed to fetch job data: ${e.toString()}');
      _appState.setLoading(false);
    }
  }

  /// Download audio stems
  Future<void> _downloadAudioStems(String jobId, String? inputFilename) async {
    try {
      // Set preparing flag BEFORE downloading to show loading indicator immediately
      _appState.setPreparingAudio(true);

      // Download all three stems in parallel
      final results = await Future.wait([
        _apiService.downloadStem(jobId: jobId, stemName: 'original'),
        _apiService.downloadStem(jobId: jobId, stemName: 'vocals'),
        _apiService.downloadStem(jobId: jobId, stemName: 'instrumental'),
      ]);

      // Store in AppState
      _appState.setAllAudioStems(
        original: results[0].isSuccess ? results[0].data : null,
        vocals: results[1].isSuccess ? results[1].data : null,
        instrumental: results[2].isSuccess ? results[2].data : null,
      );

      // Also set the vocals as the default audio with the original filename
      if (results[1].isSuccess && results[1].data != null) {
        _appState.setAudioData(results[1].data!, inputFilename ?? 'vocals.mp3');
      }
    } catch (e) {
      debugPrint('Failed to download audio stems: $e');
      _appState.setPreparingAudio(false);
    }
  }

  /// Check if currently polling
  bool get isPolling => _isPolling;

  /// Get current job ID being polled
  String? get currentJobId => _currentJobId;

  /// Dispose of resources
  void dispose() {
    stopPolling();
  }
}

