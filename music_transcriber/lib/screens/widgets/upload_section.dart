import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../models/job.dart';
import '../../providers/app_state.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/transcription_api_service.dart';
import '../../utils/audio_trim_service.dart';
import '../../widgets/processing_status_card.dart';
import '../../widgets/trim_range_slider.dart';
import '../../widgets/url_preview_panel.dart';

enum _Tab { file, url, record }

enum _RecordState { idle, recording, recorded }

/// Upload section widget — File upload (with trim), URL input (with trim), and Record Audio tabs.
class UploadSection extends StatefulWidget {
  final AppState appState;
  final TranscriptionApiService apiService;

  /// Called when the user wants to upload ready-to-go audio bytes (file or recording).
  final Future<void> Function(Uint8List bytes, String fileName)? onFileUpload;

  final Future<void> Function(String url, {double? startTime, double? endTime})? onUrlSubmitted;
  final Future<void> Function()? onCancel;
  final bool isLoadingJson;
  final bool isLoadingAudio;
  final String? loadingAudioStatus;

  const UploadSection({
    super.key,
    required this.appState,
    required this.apiService,
    this.onFileUpload,
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
  _Tab _tab = _Tab.file;

  // ---- URL state ----
  final _urlController = TextEditingController();
  String? _urlError;
  bool _isSubmittingUrl = false;
  Timer? _debounceTimer;
  bool _isFetchingMetadata = false;
  UrlMetadata? _metadata;
  String? _metadataUrl;
  double _urlTrimStart = 0;
  double _urlTrimEnd = 0;

  // ---- File state ----
  Uint8List? _fileBytes;
  String? _fileName;
  double? _fileDuration;
  double _fileTrimStart = 0;
  double _fileTrimEnd = 0;
  bool _isDecodingFile = false;
  bool _isSubmittingFile = false;

  // ---- Record state ----
  _RecordState _recordState = _RecordState.idle;
  final AudioRecorderService _recorder = AudioRecorderService();
  Uint8List? _recordedBytes;
  String _recordedMimeType = 'audio/webm';
  double _recordedDuration = 0;
  double _recordTrimStart = 0;
  double _recordTrimEnd = 0;
  Timer? _recordTimer;
  Duration _elapsed = Duration.zero;
  String? _recordError;
  String? _micLabel;
  bool _isDecodingRecording = false;
  bool _isSubmittingRecord = false;
  web.HTMLAudioElement? _previewAudio;
  String? _previewBlobUrl;
  bool _previewPlaying = false;
  JSFunction? _previewOnEnded;

  @override
  void dispose() {
    _urlController.dispose();
    _debounceTimer?.cancel();
    _recordTimer?.cancel();
    if (_recordState == _RecordState.recording) _recorder.cancel();
    _destroyPreviewAudio();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════ URL logic ══════

  void _onUrlChanged(String text) {
    setState(() => _urlError = null);
    _debounceTimer?.cancel();
    final url = text.trim();
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      if (_metadata != null || _isFetchingMetadata) {
        setState(() {
          _metadata = null;
          _metadataUrl = null;
          _isFetchingMetadata = false;
        });
      }
      return;
    }
    if (url == _metadataUrl) return;
    _debounceTimer = Timer(const Duration(milliseconds: 600), () => _fetchMetadata(url));
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
          _urlTrimStart = 0;
          _urlTrimEnd = meta.duration <= maxDur ? meta.duration : maxDur;
        });
      } else {
        setState(() {
          _metadata = null;
          _metadataUrl = null;
          _isFetchingMetadata = false;
          _urlError = response.error ?? "This URL isn't supported";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFetchingMetadata = false;
          _urlError = "Couldn't fetch URL info. You can still transcribe.";
        });
      }
    }
  }

  Future<void> _submitUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) { setState(() => _urlError = 'Please enter a URL'); return; }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _urlError = 'URL must start with http:// or https://');
      return;
    }
    if (_metadata != null && (_urlTrimEnd - _urlTrimStart) > _metadata!.maxDurationSeconds) {
      setState(() => _urlError = 'Selection is too long. Adjust the trim handles.');
      return;
    }
    if (widget.onUrlSubmitted == null) return;
    setState(() { _urlError = null; _isSubmittingUrl = true; });
    try {
      double? startTime;
      double? endTime;
      if (_metadata != null) {
        final isFullRange = _urlTrimStart <= 0.5 && (_urlTrimEnd >= _metadata!.duration - 0.5);
        if (!isFullRange) { startTime = _urlTrimStart; endTime = _urlTrimEnd; }
      }
      await widget.onUrlSubmitted!(url, startTime: startTime, endTime: endTime);
    } finally {
      if (mounted) setState(() => _isSubmittingUrl = false);
    }
  }

  // ══════════════════════════════════════════════════════════ File logic ══════

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'flac', 'm4a', 'ogg', 'webm'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final bytes = result.files.first.bytes!;
    final name = result.files.first.name;

    setState(() {
      _fileBytes = bytes;
      _fileName = name;
      _fileDuration = null;
      _fileTrimStart = 0;
      _fileTrimEnd = 0;
      _isDecodingFile = true;
    });

    final duration = await AudioTrimService.getDuration(bytes);
    if (!mounted) return;
    setState(() {
      _fileDuration = duration;
      _fileTrimStart = 0;
      _fileTrimEnd = duration ?? 0;
      _isDecodingFile = false;
    });
  }

  Future<void> _submitFile() async {
    if (_fileBytes == null || widget.onFileUpload == null) return;
    setState(() => _isSubmittingFile = true);
    try {
      final bytes = await _trimmedFileBytes();
      final name = _trimmedFileName(_fileName ?? 'audio.wav', bytes != _fileBytes);
      await widget.onFileUpload!(bytes, name);
    } finally {
      if (mounted) setState(() => _isSubmittingFile = false);
    }
  }

  Future<Uint8List> _trimmedFileBytes() async {
    final dur = _fileDuration;
    if (dur == null || dur == 0) return _fileBytes!;
    final isFullRange = _fileTrimStart <= 0.5 && (_fileTrimEnd >= dur - 0.5);
    if (isFullRange) return _fileBytes!;

    final decoded = await AudioTrimService.decode(_fileBytes!);
    if (decoded == null) return _fileBytes!;
    return AudioTrimService.trimAndEncodeWav(decoded, _fileTrimStart, _fileTrimEnd);
  }

  String _trimmedFileName(String original, bool wasTrimmed) {
    if (!wasTrimmed) return original;
    final base = original.contains('.')
        ? original.substring(0, original.lastIndexOf('.'))
        : original;
    return '$base.wav';
  }

  void _clearFile() {
    setState(() {
      _fileBytes = null;
      _fileName = null;
      _fileDuration = null;
    });
  }

  // ══════════════════════════════════════════════════════════ Record logic ═══

  Future<void> _startRecording() async {
    setState(() { _recordError = null; });
    try {
      await _recorder.start();
      setState(() {
        _recordState = _RecordState.recording;
        _elapsed = Duration.zero;
        _micLabel = _recorder.micLabel;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      setState(() => _recordError = 'Could not access microphone. Check browser permissions.');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    setState(() => _isDecodingRecording = true);

    try {
      final mimeType = _recorder.mimeType;
      final bytes = await _recorder.stop();
      if (!mounted) return;

      final duration = await AudioTrimService.getDuration(bytes);
      if (!mounted) return;

      setState(() {
        _recordedBytes = bytes;
        _recordedMimeType = mimeType;
        _recordedDuration = duration ?? _elapsed.inSeconds.toDouble();
        _recordTrimStart = 0;
        _recordTrimEnd = _recordedDuration;
        _recordState = _RecordState.recorded;
        _isDecodingRecording = false;
      });
      _initPreviewAudio(bytes, mimeType);
    } catch (e) {
      if (mounted) {
        setState(() {
          _recordState = _RecordState.idle;
          _isDecodingRecording = false;
          _recordError = 'Recording failed. Please try again.';
        });
      }
    }
  }

  void _discardRecording() {
    _recorder.cancel();
    _destroyPreviewAudio();
    setState(() {
      _recordState = _RecordState.idle;
      _recordedBytes = null;
      _recordedMimeType = 'audio/webm';
      _recordedDuration = 0;
      _elapsed = Duration.zero;
      _recordError = null;
      _previewPlaying = false;
    });
  }

  void _destroyPreviewAudio() {
    if (_previewAudio != null) {
      _previewAudio!.pause();
      if (_previewOnEnded != null) {
        _previewAudio!.removeEventListener('ended', _previewOnEnded!);
        _previewOnEnded = null;
      }
      _previewAudio!.removeAttribute('src');
      _previewAudio!.remove();
      _previewAudio = null;
    }
    if (_previewBlobUrl != null) {
      web.URL.revokeObjectURL(_previewBlobUrl!);
      _previewBlobUrl = null;
    }
  }

  void _initPreviewAudio(Uint8List bytes, String mimeType) {
    _destroyPreviewAudio();
    final blob = web.Blob(
      [bytes.buffer.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    _previewBlobUrl = web.URL.createObjectURL(blob);
    _previewAudio = web.document.createElement('audio') as web.HTMLAudioElement;
    _previewAudio!.src = _previewBlobUrl!;
    _previewAudio!.preload = 'auto';
    _previewOnEnded = ((web.Event _) {
      if (mounted) setState(() => _previewPlaying = false);
    }).toJS;
    _previewAudio!.addEventListener('ended', _previewOnEnded!);
    web.document.body!.append(_previewAudio!);
  }

  void _togglePreviewPlayback() {
    if (_previewAudio == null) return;
    if (_previewPlaying) {
      _previewAudio!.pause();
      setState(() => _previewPlaying = false);
    } else {
      if (_previewAudio!.ended) _previewAudio!.currentTime = 0;
      _previewAudio!.play();
      setState(() => _previewPlaying = true);
    }
  }

  Future<void> _submitRecording() async {
    if (_recordedBytes == null || widget.onFileUpload == null) return;
    setState(() => _isSubmittingRecord = true);
    try {
      final bytes = await _trimmedRecordingBytes();
      await widget.onFileUpload!(bytes, 'recording.wav');
    } finally {
      if (mounted) setState(() => _isSubmittingRecord = false);
    }
  }

  Future<Uint8List> _trimmedRecordingBytes() async {
    final dur = _recordedDuration;
    if (dur == 0) return _recordedBytes!;
    final isFullRange = _recordTrimStart <= 0.5 && (_recordTrimEnd >= dur - 0.5);
    if (isFullRange) return _recordedBytes!;

    final decoded = await AudioTrimService.decode(_recordedBytes!);
    if (decoded == null) return _recordedBytes!;
    return AudioTrimService.trimAndEncodeWav(decoded, _recordTrimStart, _recordTrimEnd);
  }

  // ══════════════════════════════════════════════════════════ Build ══════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appState = widget.appState;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // App icon
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
            child: Icon(Icons.graphic_eq_rounded, size: 64, color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 40),

        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(opacity: value, child: child),
          child: Text(
            'Music Transcriber',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(opacity: value, child: child),
          child: Text(
            'Upload a file, paste a URL, or record audio',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 48),

        // Loading
        if (widget.isLoadingJson || widget.isLoadingAudio)
          Column(children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary),
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
          ]),

        // Error banner
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

        ProcessingStatusCard(onCancel: widget.onCancel),

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
        SegmentedButton<_Tab>(
          segments: const [
            ButtonSegment(
              value: _Tab.file,
              label: Text('File'),
              icon: Icon(Icons.upload_file_rounded, size: 18),
            ),
            ButtonSegment(
              value: _Tab.url,
              label: Text('URL'),
              icon: Icon(Icons.link_rounded, size: 18),
            ),
            ButtonSegment(
              value: _Tab.record,
              label: Text('Record'),
              icon: Icon(Icons.mic_rounded, size: 18),
            ),
          ],
          selected: {_tab},
          expandedInsets: EdgeInsets.zero,
          onSelectionChanged: (selected) {
            setState(() {
              _tab = selected.first;
              _urlError = null;
              _recordError = null;
            });
          },
          showSelectedIcon: false,
        ),
        const SizedBox(height: 20),

        if (_tab == _Tab.file)   _buildFileTab(context)
        else if (_tab == _Tab.url) _buildUrlTab(context)
        else                       _buildRecordTab(context),
      ],
    );
  }

  // ── File tab ──────────────────────────────────────────────────────────────

  Widget _buildFileTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_fileBytes == null) {
      return FilledButton.tonalIcon(
        onPressed: _pickFile,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Select Audio File'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // File info card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.audio_file_rounded, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fileName ?? 'audio file',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatBytes(_fileBytes!.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: _clearFile,
                      tooltip: 'Remove file',
                    ),
                  ],
                ),

                if (_isDecodingFile) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Analysing audio...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ]),
                ] else if (_fileDuration != null && _fileDuration! > 0) ...[
                  const SizedBox(height: 16),
                  TrimRangeSlider(
                    totalDuration: _fileDuration!,
                    start: _fileTrimStart,
                    end: _fileTrimEnd,
                    onChanged: (range) => setState(() {
                      _fileTrimStart = range.$1;
                      _fileTrimEnd = range.$2;
                    }),
                  ),
                  const SizedBox(height: 8),
                  _buildSelectionSummary(
                    colorScheme,
                    theme,
                    start: _fileTrimStart,
                    end: _fileTrimEnd,
                    total: _fileDuration!,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        FilledButton.tonalIcon(
          onPressed: (_isDecodingFile || _isSubmittingFile) ? null : _submitFile,
          icon: _isSubmittingFile
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: colorScheme.onSurface,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(_isSubmittingFile ? 'Preparing...' : 'Transcribe'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }

  // ── URL tab ───────────────────────────────────────────────────────────────

  Widget _buildUrlTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canTranscribe = !_isSubmittingUrl &&
        (_metadata == null || (_urlTrimEnd - _urlTrimStart) <= _metadata!.maxDurationSeconds);

    return Column(
      children: [
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
                      width: 20, height: 20,
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

        if (_metadata == null)
          Text(
            'Max 10 minutes. Audio will be extracted automatically.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),

        if (_metadata != null) ...[
          const SizedBox(height: 8),
          UrlPreviewPanel(
            metadata: _metadata!,
            trimStart: _urlTrimStart,
            trimEnd: _urlTrimEnd,
            onTrimChanged: (range) => setState(() {
              _urlTrimStart = range.$1;
              _urlTrimEnd = range.$2;
            }),
          ),
        ],

        const SizedBox(height: 16),

        FilledButton.tonalIcon(
          onPressed: canTranscribe ? _submitUrl : null,
          icon: _isSubmittingUrl
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: colorScheme.onSurface,
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

  // ── Record tab ────────────────────────────────────────────────────────────

  Widget _buildRecordTab(BuildContext context) {
    return switch (_recordState) {
      _RecordState.idle     => _buildRecordIdle(context),
      _RecordState.recording => _buildRecordActive(context),
      _RecordState.recorded  => _buildRecordPreview(context),
    };
  }

  Widget _buildRecordIdle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        if (_recordError != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _recordError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton.tonalIcon(
          onPressed: _startRecording,
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Start Recording'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Records from your microphone.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        _buildMicLabel(context),
      ],
    );
  }

  Widget _buildMicLabel(BuildContext context) {
    if (_micLabel == null || _micLabel!.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_rounded, size: 13, color: colorScheme.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: 4),
          Text(
            _micLabel!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordActive(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Pulsing mic indicator
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          onEnd: () => setState(() {}),
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: child,
          ),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.error.withValues(alpha: 0.15),
              border: Border.all(color: colorScheme.error.withValues(alpha: 0.4), width: 2),
            ),
            child: Icon(Icons.mic_rounded, size: 36, color: colorScheme.error),
          ),
        ),
        const SizedBox(height: 16),

        // Elapsed timer
        Text(
          _formatDuration(_elapsed),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
            color: colorScheme.error,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Recording…',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        _buildMicLabel(context),
        const SizedBox(height: 24),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _discardRecording,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Discard'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordPreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isDecodingRecording) {
      return Column(
        children: [
          SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            'Processing recording…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.mic_rounded, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recorded audio',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      _formatDuration(Duration(seconds: _recordedDuration.round())),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      iconSize: 22,
                      visualDensity: VisualDensity.compact,
                      tooltip: _previewPlaying ? 'Pause preview' : 'Play preview',
                      onPressed: _isSubmittingRecord ? null : _togglePreviewPlayback,
                      icon: Icon(
                        _previewPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                if (_recordedDuration > 0) ...[
                  const SizedBox(height: 16),
                  TrimRangeSlider(
                    totalDuration: _recordedDuration,
                    start: _recordTrimStart,
                    end: _recordTrimEnd,
                    onChanged: (range) => setState(() {
                      _recordTrimStart = range.$1;
                      _recordTrimEnd = range.$2;
                    }),
                  ),
                  const SizedBox(height: 8),
                  _buildSelectionSummary(
                    colorScheme,
                    theme,
                    start: _recordTrimStart,
                    end: _recordTrimEnd,
                    total: _recordedDuration,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isSubmittingRecord ? null : _discardRecording,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Re-record'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _isSubmittingRecord ? null : _submitRecording,
                icon: _isSubmittingRecord
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: colorScheme.onSurface,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_isSubmittingRecord ? 'Preparing...' : 'Transcribe'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildSelectionSummary(
    ColorScheme colorScheme,
    ThemeData theme, {
    required double start,
    required double end,
    required double total,
  }) {
    final isFullRange = start <= 0.5 && end >= total - 0.5;
    return Row(
      children: [
        Icon(
          isFullRange ? Icons.check_circle_outline_rounded : Icons.content_cut_rounded,
          size: 16,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          isFullRange
              ? 'Full audio  (${_formatSecs(total)})'
              : '${_formatSecs(start)} → ${_formatSecs(end)}  (${_formatSecs(end - start)} selected)',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  static String _formatSecs(double seconds) {
    final total = seconds.round();
    final m = total ~/ 60;
    final s = total % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
