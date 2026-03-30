import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import '../services/audio_service.dart';
import '../services/transcription_api_service.dart';
import '../services/upload_service.dart';
import '../services/job_polling_service.dart';
import '../utils/file_service.dart';
import '../utils/music_utils.dart';
import '../widgets/pitch_graph.dart';
import '../widgets/audio_controls.dart';
import '../models/job.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/keyboard_shortcuts_dialog.dart';
import 'widgets/upload_layout.dart';
import 'widgets/viewer_toolbar.dart';

part 'home_screen_audio.dart';
part 'home_screen_jobs.dart';
part 'home_screen_view_controls.dart';

/// Main home screen of the Vocal Pitch Viewer app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final bool _isLoadingJson = false;
  bool _isLoadingAudio = false; // Show loading indicator while audio files are being prepared
  String? _loadingAudioStatus; // Detailed loading status message

  // Audio service
  final AudioService _audioService = AudioService();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;
  bool _audioLoaded = false;
  bool _waitingForBuffer = false; // true when play was pressed but audio is still buffering

  // Smooth playhead animation (60fps)
  Timer? _playheadAnimationTimer;
  double _lastKnownPosition = 0.0;
  DateTime? _lastPositionUpdateTime;
  bool _awaitingFirstStreamSync = false; // true until first positionStream event after play
  double _lastStreamPosition = 0.0;     // last value reported by positionStream (debug)
  int _timerTickCount = 0;              // counts timer ticks for periodic debug logging

  // API services
  late final TranscriptionApiService _apiService;
  late final UploadService _uploadService;
  late final JobPollingService _pollingService;

  // Job list state
  List<JobListItem> _completedJobs = [];
  bool _isLoadingJobs = false;

  // Audio track switching
  AudioTrackType _currentTrack = AudioTrackType.original;
  bool _isSwitchingTrack = false;

  // View window for zoom/pan (in seconds)
  double _viewStartTime = 0;
  double _viewWindowSize = 30; // Show 30 seconds at a time (adjustable via zoom)
  bool _autoScroll = true;

  // Y-axis (MIDI range) zoom — scale relative to data's natural range
  // > 1.0 = zoomed in (fewer notes visible), < 1.0 = zoomed out
  double _yZoomScale = 1.0;
  static const double _minYZoomScale = 0.5;
  static const double _maxYZoomScale = 6.0;

  // Y-axis pan offset in MIDI notes (0 = centered on data's natural range)
  double _yPanOffset = 0.0;

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

    // Initialize API services
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
    });
  }

  @override
  void dispose() {
    _stopPlayheadAnimation();
    _scrollAnimationController.removeListener(_onScrollAnimationUpdate);
    _scrollAnimationController.dispose();
    _focusNode.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _audioService.dispose();

    _pollingService.dispose();
    _apiService.dispose();

    super.dispose();
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
              // Loading overlay when loading job data OR preparing audio
              LoadingOverlay(
                isVisible: (appState.isLoading && !appState.isReady) || appState.isPreparingAudio,
                message: appState.isPreparingAudio ? 'Preparing audio files...' : null,
              ),
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

    // Load audio when entering viewer (only once)
    if (!_audioLoaded && !_isLoadingAudio && appState.audioBytes != null) {
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
                // Pitch graph with RepaintBoundary for performance isolation
                RepaintBoundary(
                  child: Builder(builder: (context) {
                    // Compute MIDI range from data, then apply Y-zoom and Y-pan
                    final pitchData = appState.pitchData!;
                    final range = pitchData.frequencyRange;
                    final baseMin = frequencyToMidi(range.$1, referenceFrequency: appState.referenceFrequency).floor() - 2.0;
                    final baseMax = frequencyToMidi(range.$2, referenceFrequency: appState.referenceFrequency).ceil() + 2.0;
                    final center = (baseMin + baseMax) / 2.0 + _yPanOffset;
                    final halfSpan = (baseMax - baseMin) / 2.0 / _yZoomScale;
                    final effectiveMinMidi = center - halfSpan;
                    final effectiveMaxMidi = center + halfSpan;

                    return PitchGraph(
                      data: pitchData,
                      chordData: appState.chordData,
                      currentTime: appState.currentTime,
                      viewStartTime: _viewStartTime,
                      viewEndTime: _viewStartTime + _viewWindowSize,
                      referenceFrequency: appState.referenceFrequency,
                      autoScroll: _autoScroll,
                      minMidi: effectiveMinMidi,
                      maxMidi: effectiveMaxMidi,
                      onSeek: _seekTo,
                      onZoom: _handleZoom,
                      onYZoom: _handleYZoom,
                      onYPan: _handleYPan,
                      onPan: _handlePan,
                    );
                  }),
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
