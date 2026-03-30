part of 'home_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _HomeScreenJobs on _HomeScreenState {
  /// Load completed jobs from API
  Future<void> _loadCompletedJobs() async {
    setState(() => _isLoadingJobs = true);

    try {
      final response = await _apiService.listJobs(status: 'completed');

      if (response.isSuccess && response.data != null) {
        setState(() {
          _completedJobs = response.data!.jobs;
          _isLoadingJobs = false;
        });
      } else {
        setState(() => _isLoadingJobs = false);
        debugPrint('Failed to load completed jobs: ${response.error}');
      }
    } catch (e) {
      setState(() => _isLoadingJobs = false);
      debugPrint('Error loading completed jobs: $e');
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
      } else {
        appState.setError('Failed to fetch pitch data: ${results.frames.error ?? "No data available"}');
        appState.setLoading(false);
        return;
      }

      if (results.chords.isSuccess && results.chords.data != null) {
        appState.setChordData(results.chords.data!);
      } else {
        appState.setError('Failed to fetch chord data: ${results.chords.error ?? "No data available"}');
        appState.setLoading(false);
        return;
      }

      await _downloadAudioStems(jobId, inputFilename);

      appState.setLoading(false);
    } catch (e) {
      appState.setError('Failed to load job data: ${e.toString()}');
      appState.setLoading(false);
    }
  }

  /// Handle job deletion
  Future<void> _onJobDeleted(String jobId) async {
    try {
      final response = await _apiService.deleteJob(jobId);

      if (response.isSuccess) {
        setState(() {
          _completedJobs.removeWhere((job) => job.id == jobId);
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

  /// Upload audio file to API for processing
  Future<void> _uploadAudioFileToAPI() async {
    final result = await FileService.pickAudioFile();

    if (!mounted) return;

    final appState = context.read<AppState>();

    if (result.isSuccess) {
      final jobId = await _uploadService.uploadAudioFile(
        fileBytes: result.data!,
        fileName: result.fileName!,
      );

      if (jobId != null && mounted) {
        _pollingService.startPolling(jobId);
      }
    } else if (result.error != null) {
      appState.setError(result.error);
    }
  }
}
