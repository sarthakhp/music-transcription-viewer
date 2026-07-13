import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../providers/app_state.dart';
import '../../services/transcription_api_service.dart';
import '../../widgets/processing_status_card.dart';
import '../../widgets/url_preview_panel.dart';

/// Upload section widget with file upload and URL input tabs
class UploadSection extends StatefulWidget {
  final AppState appState;
  final TranscriptionApiService apiService;
  final VoidCallback onUploadPressed;
  final Future<void> Function(String url, {double? startTime, double? endTime})? onUrlSubmitted;
  final Future<void> Function()? onCancel;
  final bool isLoadingJson;
  final bool isLoadingAudio;
  final String? loadingAudioStatus;

  const UploadSection({
    super.key,
    required this.appState,
    required this.apiService,
    required this.onUploadPressed,
    this.onUrlSubmitted,
    this.onCancel,
    this.isLoadingJson = false,
    this.isLoadingAudio = false,
    this.loadingAudioStatus,
  });

  @override
  State<UploadSection> createState() => _UploadSectionState();
}

class _UploadSectionState extends State<UploadSection> {
  int _selectedTab = 0; // 0 = File, 1 = URL
  final _urlController = TextEditingController();
  String? _urlError;
  bool _isSubmittingUrl = false;

  // Metadata state
  Timer? _debounceTimer;
  bool _isFetchingMetadata = false;
  UrlMetadata? _metadata;
  String? _metadataUrl; // URL that _metadata corresponds to
  double _trimStart = 0;
  double _trimEnd = 0;

  @override
  void dispose() {
    _urlController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // --- Metadata fetching --------------------------------------------------

  void _onUrlChanged(String text) {
    setState(() => _urlError = null);

    _debounceTimer?.cancel();

    final url = text.trim();
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      // Clear metadata if URL is invalid/empty.
      if (_metadata != null || _isFetchingMetadata) {
        setState(() {
          _metadata = null;
          _metadataUrl = null;
          _isFetchingMetadata = false;
        });
      }
      return;
    }

    // Don't re-fetch if URL hasn't changed.
    if (url == _metadataUrl) return;

    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _fetchMetadata(url);
    });
  }

  Future<void> _fetchMetadata(String url) async {
    setState(() {
      _isFetchingMetadata = true;
      _urlError = null;
    });

    try {
      final response = await widget.apiService.getUrlMetadata(url);

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final meta = response.data!;
        final maxDur = meta.maxDurationSeconds.toDouble();
        setState(() {
          _metadata = meta;
          _metadataUrl = url;
          _isFetchingMetadata = false;
          _trimStart = 0;
          _trimEnd = meta.duration <= maxDur ? meta.duration : maxDur;
        });
      } else {
        setState(() {
          _metadata = null;
          _metadataUrl = null;
          _isFetchingMetadata = false;
          _urlError = response.error ?? "This URL isn't supported";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingMetadata = false;
          _urlError = "Couldn't fetch URL info. You can still transcribe.";
        });
      }
    }
  }

  // --- Submit -------------------------------------------------------------

  Future<void> _submitUrl() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() => _urlError = 'Please enter a URL');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _urlError = 'URL must start with http:// or https://');
      return;
    }

    // If metadata is loaded, check trim duration.
    if (_metadata != null) {
      final selectedDuration = _trimEnd - _trimStart;
      if (selectedDuration > _metadata!.maxDurationSeconds) {
        setState(() => _urlError = 'Selection is too long. Adjust the trim handles.');
        return;
      }
    }

    if (widget.onUrlSubmitted == null) return;

    setState(() {
      _urlError = null;
      _isSubmittingUrl = true;
    });

    try {
      // Only send start/end if we have metadata and user has trimmed.
      double? startTime;
      double? endTime;
      if (_metadata != null) {
        final isFullRange = _trimStart <= 0.5 &&
            (_trimEnd >= _metadata!.duration - 0.5);
        if (!isFullRange) {
          startTime = _trimStart;
          endTime = _trimEnd;
        }
      }
      await widget.onUrlSubmitted!(url, startTime: startTime, endTime: endTime);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingUrl = false);
      }
    }
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appState = widget.appState;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated app icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          ),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.6),
                  colorScheme.primaryContainer.withValues(alpha: 0.2),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Title
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(opacity: value, child: child),
          child: Text(
            'RiyazScope',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Subtitle
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(opacity: value, child: child),
          child: Text(
            'Upload an audio file or paste a YouTube URL',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 48),

        // Loading indicator
        if (widget.isLoadingJson || widget.isLoadingAudio)
          Column(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.loadingAudioStatus ??
                    (widget.isLoadingJson ? 'Loading pitch data...' : 'Loading audio...'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontStyle: widget.loadingAudioStatus != null ? FontStyle.italic : null,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),

        // Error message
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: appState.errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: colorScheme.error),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            appState.errorMessage!,
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colorScheme.error),
                          onPressed: () => appState.setError(null),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Processing status card
        ProcessingStatusCard(onCancel: widget.onCancel),

        // Input area (hidden during upload/processing)
        if (!appState.isUploading && !appState.isProcessing) ...[
          const SizedBox(height: 24),
          _buildInputArea(context),
        ],
      ],
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Column(
      children: [
        // Tab switcher
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('File'),
              icon: Icon(Icons.upload_file_rounded, size: 18),
            ),
            ButtonSegment(
              value: 1,
              label: Text('URL'),
              icon: Icon(Icons.link_rounded, size: 18),
            ),
          ],
          selected: {_selectedTab},
          expandedInsets: EdgeInsets.zero,
          onSelectionChanged: (selected) {
            setState(() {
              _selectedTab = selected.first;
              _urlError = null;
            });
          },
          showSelectedIcon: false,
        ),
        const SizedBox(height: 20),

        // Tab content
        if (_selectedTab == 0)
          FilledButton.tonalIcon(
            onPressed: widget.onUploadPressed,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload Audio for Processing'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          )
        else
          _buildUrlInput(context),
      ],
    );
  }

  Widget _buildUrlInput(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canTranscribe = !_isSubmittingUrl &&
        (_metadata == null ||
            (_trimEnd - _trimStart) <= _metadata!.maxDurationSeconds);

    return Column(
      children: [
        // URL text field
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: 'https://www.youtube.com/watch?v=...',
            prefixIcon: const Icon(Icons.link_rounded),
            errorText: _urlError,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: _isFetchingMetadata
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _urlController.clear();
                          _debounceTimer?.cancel();
                          setState(() {
                            _urlError = null;
                            _metadata = null;
                            _metadataUrl = null;
                            _isFetchingMetadata = false;
                          });
                        },
                      )
                    : null,
          ),
          keyboardType: TextInputType.url,
          onChanged: _onUrlChanged,
          onSubmitted: (_) => _submitUrl(),
        ),
        const SizedBox(height: 8),

        // Helper text (only when no metadata shown)
        if (_metadata == null)
          Text(
            'Max 10 minutes. Audio will be extracted automatically.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),

        // Preview panel (shown when metadata is loaded)
        if (_metadata != null) ...[
          const SizedBox(height: 8),
          UrlPreviewPanel(
            metadata: _metadata!,
            trimStart: _trimStart,
            trimEnd: _trimEnd,
            onTrimChanged: (range) {
              setState(() {
                _trimStart = range.$1;
                _trimEnd = range.$2;
              });
            },
          ),
        ],

        const SizedBox(height: 16),

        // Transcribe button — always available, never blocked by metadata loading
        FilledButton.tonalIcon(
          onPressed: canTranscribe ? _submitUrl : null,
          icon: _isSubmittingUrl
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onSurface,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(_isSubmittingUrl ? 'Submitting...' : 'Transcribe'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }
}
