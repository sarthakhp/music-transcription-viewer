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
import '../services/user_settings.dart';
import '../config/api_config.dart';
import '../utils/file_service.dart';
import '../utils/music_utils.dart';
import '../utils/performance_monitor.dart';
import '../models/view_state.dart';
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
  StreamSubscription<AudioPlayerState>? _processingStateSubscription;
  bool _audioLoaded = false;
  bool _waitingForBuffer = false; // true when play was pressed but audio is still buffering

  // Smooth playhead animation (60fps)
  Timer? _playheadAnimationTimer;
  double _lastKnownPosition = 0.0;
  DateTime? _lastPositionUpdateTime;
  bool _awaitingFirstStreamSync = false; // true until first positionStream event after play
  double _lastStreamPosition = 0.0;     // last value reported by positionStream (debug)
  int _timerTickCount = 0;              // counts timer ticks for periodic debug logging

  // Persisted user settings
  final UserSettings _userSettings = UserSettings();

  // API services
  late final TranscriptionApiService _apiService;
  late final UploadService _uploadService;
  late final JobPollingService _pollingService;

  // Job list state
  List<JobListItem> _completedJobs = [];
  List<JobListItem> _failedJobs = [];
  bool _isLoadingJobs = false;

  // Audio track switching
  AudioTrackType _currentTrack = AudioTrackType.original;
  bool _isSwitchingTrack = false;

  // Layer visibility toggles for the pitch graph
  bool _showVocals = true;
  bool _showBass = true;
  bool _showOther = true;

  // Minimum confidence thresholds for each layer (0.0 = show all)
  double _vocalsMinConfidence = 0.0;
  double _bassMinConfidence = 0.0;
  double _otherMinConfidence = 0.0;

  // Playback speed (preset steps: 0.5, 0.75, 1.0, 1.25, 1.5, 2.0)
  double _playbackSpeed = 1.0;

  // Transpose: semitones offset applied to visual display AND audio pitch shift
  int _transposeAmount = 0;

  // Sargam notation display
  bool _sargamEnabled = false;
  int _scaleRoot = 0; // 0=C, 1=C#, 2=D, ... 11=B

  // Vocal detail (frames per second for pitch display)
  int _vocalDetail = 10;

  // View state (pan, zoom, auto-scroll) — isolated from main widget tree
  final ViewState _viewState = ViewState();

  // Smooth scrolling animation (needs TickerProvider, so stays here)
  late AnimationController _scrollAnimationController;
  Animation<double>? _scrollAnimation;

  // Keyboard focus
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    PerformanceMonitor.instance.start();

    // Initialize smooth scroll animation controller
    _scrollAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scrollAnimationController.addListener(_onScrollAnimationUpdate);

    // Initialize API services
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

    // Load persisted user settings, then apply to state
    _userSettings.load().then((_) {
      if (!mounted) return;
      setState(() {
        _playbackSpeed = _userSettings.playbackSpeed;
        _transposeAmount = _userSettings.transposeAmount;
        _sargamEnabled = _userSettings.sargamEnabled;
        _scaleRoot = _userSettings.scaleRoot;
        _vocalDetail = _userSettings.vocalDetail;
      });
      final appState = context.read<AppState>();
      appState.setReferenceFrequency(_userSettings.referenceFrequency);
    });

    // Load completed jobs after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompletedJobs();
    });
  }

  @override
  void dispose() {
    _stopPlayheadAnimation();
    _scrollAnimationController.removeListener(_onScrollAnimationUpdate);
    _scrollAnimationController.dispose();
    _viewState.dispose();
    _focusNode.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _audioService.dispose();

    PerformanceMonitor.instance.stop();
    _pollingService.dispose();
    _apiService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Only rebuild the outer shell when ready/loading state changes — NOT on
    // every currentTime tick. Fast-changing fields (currentTime, isPlaying,
    // duration) are consumed via Consumer/Selector inside specific widgets.
    return Selector<AppState, ({bool isReady, bool isLoading, bool isPreparingAudio})>(
      selector: (_, s) => (isReady: s.isReady, isLoading: s.isLoading, isPreparingAudio: s.isPreparingAudio),
      builder: (context, shell, _) {
        final appState = context.read<AppState>();

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
                  if (shell.isReady)
                    IconButton(
                      icon: const Icon(Icons.keyboard_rounded),
                      onPressed: () => KeyboardShortcutsDialog.show(context),
                      tooltip: 'Keyboard shortcuts',
                    ),
                  if (shell.isReady)
                    TextButton.icon(
                      onPressed: () {
                        _stopPlayheadAnimation();
                        _audioService.stop();
                        _audioLoaded = false;
                        _positionSubscription?.cancel();
                        _durationSubscription?.cancel();
                        _playingSubscription?.cancel();
                        _processingStateSubscription?.cancel();
                        _viewState.resetZoom();
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
                    child: shell.isReady
                        ? _buildViewerLayout(context, appState)
                        : _buildUploadLayout(context, appState),
                  ),
                  LoadingOverlay(
                    isVisible: (shell.isLoading && !shell.isReady) || shell.isPreparingAudio,
                    message: shell.isPreparingAudio ? 'Preparing audio files...' : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadLayout(BuildContext context, AppState appState) {
    return UploadLayout(
      appState: appState,
      apiService: _apiService,
      completedJobs: _completedJobs,
      failedJobs: _failedJobs,
      isLoadingJobs: _isLoadingJobs,
      onJobSelected: _onJobSelected,
      onJobDeleted: _onJobDeleted,
      onJobRetry: _onJobRetry,
      onUploadPressed: _uploadAudioFileToAPI,
      onUrlSubmitted: _submitUrlForTranscription,
      onCancel: _cancelCurrentJob,
      isLoadingJson: _isLoadingJson,
      isLoadingAudio: _isLoadingAudio,
      loadingAudioStatus: _loadingAudioStatus,
      isRemote: ApiConfig.isRemote,
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
          showVocals: _showVocals,
          showBass: _showBass,
          showOther: _showOther,
          onVocalsToggled: (v) => setState(() => _showVocals = v),
          onBassToggled: (v) => setState(() => _showBass = v),
          onOtherToggled: (v) => setState(() => _showOther = v),
          vocalsMinConfidence: _vocalsMinConfidence,
          bassMinConfidence: _bassMinConfidence,
          otherMinConfidence: _otherMinConfidence,
          onVocalsConfidenceChanged: (v) => setState(() => _vocalsMinConfidence = v),
          onBassConfidenceChanged: (v) => setState(() => _bassMinConfidence = v),
          onOtherConfidenceChanged: (v) => setState(() => _otherMinConfidence = v),
          vocalDetail: _vocalDetail,
          onVocalDetailChanged: (v) {
            setState(() => _vocalDetail = v);
            _userSettings.saveVocalDetail(v);
          },
        ),

        // Main content area — during pan/zoom, only the CustomPaint repaints
        // via ViewState's repaint listenable. No widget rebuild at all.
        Expanded(
          child: ClipRect(
            child: Stack(
              children: [
                RepaintBoundary(
                  child: Selector<AppState, double>(
                    selector: (_, s) => s.currentTime,
                    builder: (context, currentTime, _) {
                      // Update base MIDI range (only changes when data/transpose changes)
                      final pitchData = appState.pitchData!;
                      final range = pitchData.frequencyRange;
                      double baseMin = frequencyToMidi(range.$1, referenceFrequency: appState.referenceFrequency).floor() - 2.0;
                      double baseMax = frequencyToMidi(range.$2, referenceFrequency: appState.referenceFrequency).ceil() + 2.0;
                      final instrData = appState.instrumentData;
                      if (instrData != null) {
                        final (instrMin, instrMax) = instrData.midiRange;
                        if (instrMin - 1.0 < baseMin) baseMin = instrMin - 1.0;
                        if (instrMax + 1.0 > baseMax) baseMax = instrMax + 1.0;
                      }
                      _viewState.setBaseMidiRange(baseMin + _transposeAmount, baseMax + _transposeAmount);

                      return PitchGraph(
                        viewState: _viewState,
                        data: pitchData,
                        chordData: appState.chordData,
                        instrumentData: appState.instrumentData,
                        currentTime: currentTime,
                        referenceFrequency: appState.referenceFrequency,
                        showVocals: _showVocals,
                        showBass: _showBass,
                        showOther: _showOther,
                        vocalsMinConfidence: _vocalsMinConfidence,
                        bassMinConfidence: _bassMinConfidence,
                        otherMinConfidence: _otherMinConfidence,
                        transposeAmount: _transposeAmount,
                        sargamEnabled: _sargamEnabled,
                        scaleRoot: _scaleRoot,
                        vocalDetail: _vocalDetail,
                        onSeek: _seekTo,
                        onZoom: _handleZoom,
                        onYZoom: _handleYZoom,
                        onYPan: _handleYPan,
                        onPan: _handlePan,
                      );
                    },
                  ),
                ),

                Positioned(
                  bottom: 8,
                  right: 8,
                  child: ListenableBuilder(
                    listenable: _viewState,
                    builder: (context, _) {
                      final isOn = _viewState.autoScroll;
                      return GestureDetector(
                        onTap: () => _viewState.setAutoScroll(!isOn),
                        child: Chip(
                          avatar: Icon(
                            isOn ? Icons.play_arrow_rounded : Icons.play_arrow_outlined,
                            size: 16,
                            color: isOn
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          label: Text(
                            'Auto-scroll',
                            style: TextStyle(
                              fontSize: 11,
                              color: isOn
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          backgroundColor: isOn
                              ? colorScheme.secondaryContainer.withValues(alpha: 0.8)
                              : colorScheme.surface.withValues(alpha: 0.6),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // AudioControls — rebuilds on currentTime/isPlaying/duration (Selector)
        // and on viewWindowSize (ListenableBuilder).
        Selector<AppState, ({double currentTime, bool isPlaying, double duration, double referenceFrequency})>(
          selector: (_, s) => (
            currentTime: s.currentTime,
            isPlaying: s.isPlaying,
            duration: s.duration,
            referenceFrequency: s.referenceFrequency,
          ),
          builder: (context, audio, _) => ListenableBuilder(
            listenable: _viewState,
            builder: (context, _) => AudioControls(
              isPlaying: audio.isPlaying,
              currentTime: audio.currentTime,
              duration: audio.duration > 0 ? audio.duration : appState.pitchData!.maxTime,
              referenceFrequency: audio.referenceFrequency,
              onPlayPause: () => _audioService.togglePlayPause(),
              onStop: () => _audioService.stop(),
              onSeek: _seekTo,
              onReferenceFrequencyChange: (frequency) {
                appState.setReferenceFrequency(frequency);
                _userSettings.saveReferenceFrequency(frequency);
              },
              onZoomIn: () => _viewState.zoomY(ViewState.zoomFactor),
              onZoomOut: () => _viewState.zoomY(1.0 / ViewState.zoomFactor),
              viewWindowSize: _viewState.viewWindowSize,
              playbackSpeed: _playbackSpeed,
              onSpeedChanged: (speed) {
                setState(() => _playbackSpeed = speed);
                _audioService.setSpeed(speed);
                _userSettings.savePlaybackSpeed(speed);
              },
              transposeAmount: _transposeAmount,
              onTransposeChanged: (n) {
                setState(() => _transposeAmount = n);
                _audioService.setPitchSemitones(n);
                _userSettings.saveTransposeAmount(n);
              },
              sargamEnabled: _sargamEnabled,
              onSargamToggled: (v) {
                setState(() => _sargamEnabled = v);
                _userSettings.saveSargamEnabled(v);
              },
              scaleRoot: _scaleRoot,
              onScaleRootChanged: (v) {
                setState(() => _scaleRoot = v);
                _userSettings.saveScaleRoot(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
