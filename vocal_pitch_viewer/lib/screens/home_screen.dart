import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/audio_service.dart';
import '../services/transcription_api_service.dart';
import '../services/upload_service.dart';
import '../services/job_polling_service.dart';
import '../utils/file_service.dart';
import '../widgets/pitch_graph.dart';
import '../widgets/audio_controls.dart';
import '../models/job.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/keyboard_shortcuts_dialog.dart';
import 'widgets/upload_layout.dart';
import 'widgets/viewer_toolbar.dart';

/// Main home screen of the Vocal Pitch Viewer app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final bool _isLoadingJson = false;
  final bool _isLoadingAudio = false;
  String? _loadingAudioStatus; // Detailed loading status message

  // Audio service
  final AudioService _audioService = AudioService();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  bool _audioLoaded = false;

  // API services (NEW)
  late final TranscriptionApiService _apiService;
  late final UploadService _uploadService;
  late final JobPollingService _pollingService;

  // Job list state
  List<JobListItem> _completedJobs = [];
  bool _isLoadingJobs = false;

  // Audio track switching - store pre-computed data URIs for instant switching
  AudioTrackType _currentTrack = AudioTrackType.original;
  bool _isSwitchingTrack = false;

  // View window for zoom/pan (in seconds)
  double _viewStartTime = 0;
  double _viewWindowSize = 30; // Show 30 seconds at a time (adjustable via zoom)
  bool _autoScroll = true;

  // Smooth scrolling animation
  late AnimationController _scrollAnimationController;
  Animation<double>? _scrollAnimation;

  // Zoom constraints
  static const double _minWindowSize = 5; // Minimum 5 seconds view (max zoom in)
  static const double _maxWindowSize = 120; // Maximum 120 seconds view (max zoom out)
  static const double _zoomFactor = 1.2; // Zoom step factor

  // Keyboard focus
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Initialize smooth scroll animation controller
    _scrollAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scrollAnimationController.addListener(_onScrollAnimationUpdate);

    // Initialize API services (NEW)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      _apiService = TranscriptionApiService();
      _uploadService = UploadService(
        apiService: _apiService,
        appState: appState,
      );
      _pollingService = JobPollingService(
        apiService: _apiService,
        appState: appState,
      );

      // Load completed jobs
      _loadCompletedJobs();

      // Auto-load sample data on startup (DISABLED - Phase 3)
      // Users should upload their own audio files via the API
      // _loadSampleData();
    });
  }

  /// Load completed jobs from API
  Future<void> _loadCompletedJobs() async {
    setState(() {
      _isLoadingJobs = true;
    });

    try {
      final response = await _apiService.listJobs(status: 'completed');

      if (response.isSuccess && response.data != null) {
        setState(() {
          _completedJobs = response.data!.jobs;
          _isLoadingJobs = false;
        });
      } else {
        setState(() {
          _isLoadingJobs = false;
        });
        // Don't show error for failed job list fetch - it's not critical
        debugPrint('Failed to load completed jobs: ${response.error}');
      }
    } catch (e) {
      setState(() {
        _isLoadingJobs = false;
      });
      debugPrint('Error loading completed jobs: $e');
    }
  }

  /// Handle job selection - load job data and display
  Future<void> _onJobSelected(String jobId) async {
    final appState = context.read<AppState>();

    try {
      appState.setLoading(true);
      appState.setError(null);

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

      // Download audio stems (original, vocals, instrumental)
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
        // Remove job from local list
        setState(() {
          _completedJobs.removeWhere((job) => job.id == jobId);
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Job deleted successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete job: ${response.error}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting job: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Download audio stems for a job
  Future<void> _downloadAudioStems(String jobId, String? inputFilename) async {
    final appState = context.read<AppState>();

    try {
      // Download all three stems in parallel
      final results = await Future.wait([
        _apiService.downloadStem(jobId: jobId, stemName: 'original'),
        _apiService.downloadStem(jobId: jobId, stemName: 'vocals'),
        _apiService.downloadStem(jobId: jobId, stemName: 'instrumental'),
      ]);

      // Store in AppState
      appState.setAllAudioStems(
        original: results[0].isSuccess ? results[0].data : null,
        vocals: results[1].isSuccess ? results[1].data : null,
        instrumental: results[2].isSuccess ? results[2].data : null,
      );

      // Also set the vocals as the default audio with the original filename
      if (results[1].isSuccess && results[1].data != null) {
        appState.setAudioData(results[1].data!, inputFilename ?? 'vocals.mp3');
      } else if (results[0].isSuccess && results[0].data != null) {
        // Fallback to original if vocals not available
        appState.setAudioData(results[0].data!, inputFilename ?? 'original.mp3');
      }
    } catch (e) {
      debugPrint('Error downloading audio stems: $e');
      appState.setError('Failed to download audio: ${e.toString()}');
    }
  }

  void _onScrollAnimationUpdate() {
    if (_scrollAnimation != null) {
      setState(() {
        _viewStartTime = _scrollAnimation!.value;
      });
    }
  }

  /// Switch to a different audio track instantly using pre-loaded players
  Future<void> _switchTrack(AudioTrackType newTrack) async {
    if (newTrack == _currentTrack) return;
    if (!_audioService.isTrackLoaded(newTrack)) return;
    if (_isSwitchingTrack) return; // Prevent double-switching

    setState(() => _isSwitchingTrack = true);

    try {
      // Use instant track switching (switches between pre-loaded players)
      final success = await _audioService.switchToTrack(newTrack);

      if (mounted) {
        setState(() {
          if (success) {
            _currentTrack = newTrack;
          }
          _isSwitchingTrack = false;
        });
      }
    } catch (e) {
      // Ensure loading state is reset even on error
      if (mounted) {
        setState(() => _isSwitchingTrack = false);
      }
    }
  }

  @override
  void dispose() {
    _scrollAnimationController.removeListener(_onScrollAnimationUpdate);
    _scrollAnimationController.dispose();
    _focusNode.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _audioService.dispose();

    // Dispose API services (NEW)
    _pollingService.dispose();
    _apiService.dispose();

    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final appState = context.read<AppState>();
    if (!appState.isReady) return KeyEventResult.ignored;

    final currentTime = appState.currentTime;
    final maxTime = appState.pitchData?.maxTime ?? 120;

    // Space - Play/Pause
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _audioService.togglePlayPause();
      return KeyEventResult.handled;
    }

    // Left arrow - Seek back 5s
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekTo((currentTime - 5).clamp(0, maxTime));
      return KeyEventResult.handled;
    }

    // Right arrow - Seek forward 5s
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekTo((currentTime + 5).clamp(0, maxTime));
      return KeyEventResult.handled;
    }

    // + or = - Zoom in
    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add) {
      _zoomIn();
      return KeyEventResult.handled;
    }

    // - - Zoom out
    if (event.logicalKey == LogicalKeyboardKey.minus) {
      _zoomOut();
      return KeyEventResult.handled;
    }

    // 0 - Reset zoom
    if (event.logicalKey == LogicalKeyboardKey.digit0) {
      _resetZoom();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _updateViewWindow(double currentTime, double maxTime) {
    if (!_autoScroll) return;

    final viewEndTime = _viewStartTime + _viewWindowSize;

    // If playhead is near the end of the view window (within 10%), scroll
    if (currentTime > viewEndTime - _viewWindowSize * 0.1) {
      final newStartTime = (currentTime - _viewWindowSize * 0.1).clamp(0.0, max(0.0, maxTime - _viewWindowSize).toDouble());
      _animateScrollTo(newStartTime);
    }
    // If playhead is before the view window, scroll back
    else if (currentTime < _viewStartTime) {
      final newStartTime = currentTime.clamp(0.0, max(0.0, maxTime - _viewWindowSize).toDouble());
      _animateScrollTo(newStartTime);
    }
  }

  void _zoomIn() {
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    final centerTime = _viewStartTime + _viewWindowSize / 2;
    setState(() {
      _viewWindowSize = (_viewWindowSize / _zoomFactor).clamp(_minWindowSize, _maxWindowSize);
      _viewStartTime = (centerTime - _viewWindowSize / 2).clamp(0, max(0, maxTime - _viewWindowSize));
      _autoScroll = false;
    });
    _reEnableAutoScrollAfterDelay();
  }

  void _zoomOut() {
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    final centerTime = _viewStartTime + _viewWindowSize / 2;
    setState(() {
      _viewWindowSize = (_viewWindowSize * _zoomFactor).clamp(_minWindowSize, _maxWindowSize);
      _viewStartTime = (centerTime - _viewWindowSize / 2).clamp(0, max(0, maxTime - _viewWindowSize));
      _autoScroll = false;
    });
    _reEnableAutoScrollAfterDelay();
  }

  void _resetZoom() {
    setState(() {
      _viewWindowSize = 30;
      _viewStartTime = 0;
      _autoScroll = true;
    });
  }

  void _handleZoom(double zoomDelta, double focalPointRatio) {
    // zoomDelta > 0 means zoom in, < 0 means zoom out
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120.0;

    // Calculate the time at the focal point
    final focalTime = _viewStartTime + _viewWindowSize * focalPointRatio;

    // Apply zoom
    final newWindowSize = (zoomDelta > 0
        ? _viewWindowSize / (1 + zoomDelta.abs() * 0.1)
        : _viewWindowSize * (1 + zoomDelta.abs() * 0.1)
    ).clamp(_minWindowSize, _maxWindowSize);

    // Adjust start time to keep focal point stationary
    final newStartTime = (focalTime - newWindowSize * focalPointRatio).clamp(0.0, max(0.0, maxTime - newWindowSize).toDouble());

    setState(() {
      _viewWindowSize = newWindowSize;
      _viewStartTime = newStartTime;
      _autoScroll = false;
    });
    _reEnableAutoScrollAfterDelay();
  }

  void _handlePan(double panDelta) {
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;

    // Update immediately for direct mouse tracking (no animation)
    setState(() {
      _viewStartTime = (_viewStartTime + panDelta).clamp(0.0, max(0.0, maxTime - _viewWindowSize));
      _autoScroll = false;
    });
    _reEnableAutoScrollAfterDelay();
  }

  void _animateScrollTo(double targetTime) {
    _scrollAnimation = Tween<double>(
      begin: _viewStartTime,
      end: targetTime,
    ).animate(CurvedAnimation(
      parent: _scrollAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _scrollAnimationController.forward(from: 0);
  }

  void _reEnableAutoScrollAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _autoScroll = true);
      }
    });
  }

  void _seekTo(double time) {
    _audioService.seekToSeconds(time);

    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    final viewEndTime = _viewStartTime + _viewWindowSize;

    // Only adjust view if seek position is outside current view
    final isOutsideView = time < _viewStartTime || time > viewEndTime;

    setState(() {
      _autoScroll = false;
    });

    if (isOutsideView) {
      // Smoothly scroll to center the view on the seek position
      final newStartTime = (time - _viewWindowSize / 2).clamp(0.0, max(0.0, maxTime - _viewWindowSize).toDouble());
      _animateScrollTo(newStartTime);
    }

    // Re-enable auto-scroll after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _autoScroll = true);
      }
    });
  }

  Future<void> _loadAudio(AppState appState) async {
    if (appState.audioBytes == null || _audioLoaded) return;

    final mimeType = _getMimeType(appState.audioFileName ?? '');

    // Load all available audio stems (NEW - Phase 3)
    bool success = false;

    // Load additional stems if available from API
    // Priority: original > vocals > fallback to appState.audioBytes
    if (appState.originalAudio != null) {
      await _audioService.loadTrack(
        AudioTrackType.original,
        appState.originalAudio!,
        'audio/mpeg',
        setActive: true, // Original is the preferred active track
      );
      success = true;
    }

    if (appState.vocalsAudio != null) {
      await _audioService.loadTrack(
        AudioTrackType.vocal,
        appState.vocalsAudio!,
        'audio/mpeg',
        setActive: !success, // Set as active only if original wasn't loaded
      );
      if (!success) {
        success = true;
      }
    }

    if (appState.instrumentalAudio != null) {
      await _audioService.loadTrack(
        AudioTrackType.instrumental,
        appState.instrumentalAudio!,
        'audio/mpeg',
        setActive: false, // Never set instrumental as default active
      );
    }

    // Fallback: if no API stems available, load from appState.audioBytes
    if (!success) {
      success = await _audioService.loadFromBytes(appState.audioBytes!, mimeType);
    }

    if (success && mounted) {
      setState(() => _audioLoaded = true);

      // Listen to position updates
      _positionSubscription = _audioService.positionStream.listen((position) {
        if (mounted) {
          final time = position.inMilliseconds / 1000.0;
          appState.setCurrentTime(time);
          _updateViewWindow(time, appState.pitchData?.maxTime ?? 120);
        }
      });

      // Listen to duration updates
      _durationSubscription = _audioService.durationStream.listen((duration) {
        if (mounted && duration != null) {
          appState.setDuration(duration.inMilliseconds / 1000.0);
        }
      });

      // Listen to playing state
      _playingSubscription = _audioService.playingStream.listen((playing) {
        if (mounted) {
          appState.setPlaying(playing);
        }
      });
    }
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

  /// Upload audio file to API for processing (NEW)
  Future<void> _uploadAudioFileToAPI() async {
    final result = await FileService.pickAudioFile();

    if (!mounted) return;

    final appState = context.read<AppState>();

    if (result.isSuccess) {
      // Upload file
      final jobId = await _uploadService.uploadAudioFile(
        fileBytes: result.data!,
        fileName: result.fileName!,
      );

      if (jobId != null && mounted) {
        // Start polling for job status
        _pollingService.startPolling(jobId);
      }
    } else if (result.error != null) {
      appState.setError(result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.graphic_eq_rounded, color: colorScheme.primary),
                const SizedBox(width: 12),
                const Text('Vocal Pitch Viewer'),
              ],
            ),
            actions: [
              // Keyboard shortcuts help button
              if (appState.isReady)
                IconButton(
                  icon: const Icon(Icons.keyboard_rounded),
                  onPressed: () => KeyboardShortcutsDialog.show(context),
                  tooltip: 'Keyboard shortcuts',
                ),
              // Load New button
              if (appState.isReady)
                TextButton.icon(
                  onPressed: () {
                    _audioService.stop();
                    _audioLoaded = false;
                    _positionSubscription?.cancel();
                    _durationSubscription?.cancel();
                    _playingSubscription?.cancel();
                    appState.reset();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Load New'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: appState.isReady
                    ? _buildViewerLayout(context, appState)
                    : _buildUploadLayout(context, appState),
              ),
              // Loading overlay when loading job data
              LoadingOverlay(isVisible: appState.isLoading && !appState.isReady),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildUploadLayout(BuildContext context, AppState appState) {
    return UploadLayout(
      appState: appState,
      completedJobs: _completedJobs,
      isLoadingJobs: _isLoadingJobs,
      onJobSelected: _onJobSelected,
      onJobDeleted: _onJobDeleted,
      onUploadPressed: _uploadAudioFileToAPI,
      isLoadingJson: _isLoadingJson,
      isLoadingAudio: _isLoadingAudio,
      loadingAudioStatus: _loadingAudioStatus,
    );
  }



  Widget _buildViewerLayout(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 800;

    // Load audio when entering viewer
    if (!_audioLoaded && appState.audioBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAudio(appState);
      });
    }

    return Column(
      children: [
        // Top bar with metadata summary and view controls
        ViewerToolbar(
          appState: appState,
          audioService: _audioService,
          currentTrack: _currentTrack,
          isSwitchingTrack: _isSwitchingTrack,
          onTrackChanged: _switchTrack,
          isNarrow: isNarrow,
        ),

        // Main content area - pitch graph with zoom controls
        Expanded(
          child: ClipRect(
            child: Stack(
              children: [
                // Pitch graph
                PitchGraph(
                  data: appState.pitchData!,
                  chordData: appState.chordData,
                  currentTime: appState.currentTime,
                  viewStartTime: _viewStartTime,
                  viewEndTime: _viewStartTime + _viewWindowSize,
                  referenceFrequency: appState.referenceFrequency,
                  autoScroll: _autoScroll,
                  onSeek: _seekTo,
                  onZoom: _handleZoom,
                  onPan: _handlePan,
                ),

              // Auto-scroll indicator (bottom-right corner)
              if (_autoScroll)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Chip(
                    avatar: Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: colorScheme.onSecondaryContainer,
                    ),
                    label: Text(
                      'Auto-scroll',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.8),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        ),

        // Audio controls bar
        AudioControls(
          isPlaying: appState.isPlaying,
          currentTime: appState.currentTime,
          duration: appState.duration > 0 ? appState.duration : appState.pitchData!.maxTime,
          referenceFrequency: appState.referenceFrequency,
          onPlayPause: () => _audioService.togglePlayPause(),
          onStop: () => _audioService.stop(),
          onSeek: _seekTo,
          onReferenceFrequencyChange: (frequency) => appState.setReferenceFrequency(frequency),
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          viewWindowSize: _viewWindowSize,
        ),
      ],
    );
  }

}

