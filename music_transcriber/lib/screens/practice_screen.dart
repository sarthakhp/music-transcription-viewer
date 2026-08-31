import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/audio_export_service.dart';
import '../services/platform_audio_player.dart';
import '../services/platform_audio_player.dart'
    if (dart.library.io) '../services/platform_audio_player_native.dart'
    if (dart.library.js_interop) '../services/platform_audio_player_web.dart'
    as platform;
import '../utils/download_helper.dart';
import '../widgets/audio_controls/speed_control.dart';
import '../widgets/audio_controls/transpose_control.dart';

/// Fully client-side practice tool: upload any audio or video file, play it
/// back with pitch transpose + speed control, and export the modified audio
/// — no backend, no transcription. Deliberately independent of [AppState],
/// which is shaped around the transcription job model this screen doesn't use.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  Uint8List? _fileBytes;
  String? _fileName;

  PlatformAudioPlayer? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;

  bool _isLoadingFile = false;
  bool _isExporting = false;
  double _exportProgress = 0;
  String? _error;

  int _semitones = 0;
  double _speed = 1.0;

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // FileType.audio restricts the OS picker to audio/* — widen it to
    // include common video containers too, since only the audio track is
    // used (see _mimeTypeFor) and this is often how people practice with a
    // downloaded music video.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'mp3', 'wav', 'ogg', 'm4a', 'flac', 'webm', 'aac',
        'mp4', 'm4v', 'mov', 'mkv', 'avi',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
      return;
    }
    final bytes = result.files.first.bytes!;
    final name = result.files.first.name;

    setState(() {
      _error = null;
      _isLoadingFile = true;
      _fileBytes = bytes;
      _fileName = name;
      _semitones = 0;
      _speed = 1.0;
      _position = Duration.zero;
      _duration = null;
    });

    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playingSub?.cancel();
    await _player?.dispose();

    final player = platform.createPlatformAudioPlayer();
    _positionSub = player.positionStream.listen((p) => setState(() => _position = p));
    _durationSub = player.durationStream.listen((d) => setState(() => _duration = d));
    _playingSub = player.playingStream.listen((p) => setState(() => _isPlaying = p));

    try {
      await player.load(bytes, _mimeTypeFor(name));
      _player = player;
    } catch (e, st) {
      debugPrint('[Practice] load failed for "$name": $e\n$st');
      setState(() => _error = 'Could not load "$name" — is it a valid audio or video file?');
    } finally {
      if (mounted) setState(() => _isLoadingFile = false);
    }
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (_isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> _seek(Duration position) async {
    await _player?.seek(position);
  }

  void _onTransposeChanged(int semitones) {
    setState(() => _semitones = semitones);
    _player?.setPitchSemitones(semitones);
  }

  Future<void> _onSpeedChanged(double speed) async {
    setState(() => _speed = speed);
    await _player?.setSpeed(speed);
  }

  Future<void> _download() async {
    final bytes = _fileBytes;
    final name = _fileName;
    if (bytes == null || name == null) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0;
      _error = null;
    });
    try {
      final mp3Bytes = await AudioExportService.exportMp3(
        bytes,
        semitones: _semitones,
        speed: _speed,
        onProgress: (fraction) {
          if (mounted) setState(() => _exportProgress = fraction);
        },
      );
      downloadBytes(mp3Bytes, _exportFilename(name), 'audio/mpeg');
    } catch (e) {
      setState(() => _error = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _exportFilename(String sourceName) {
    final dot = sourceName.lastIndexOf('.');
    final baseName = dot == -1 ? sourceName : sourceName.substring(0, dot);
    final suffix = StringBuffer();
    if (_semitones != 0) {
      suffix.write(_semitones > 0 ? '_+${_semitones}st' : '_${_semitones}st');
    }
    if (_speed != 1.0) {
      suffix.write('_${_speed}x');
    }
    return '$baseName$suffix.mp3';
  }

  String _mimeTypeFor(String fileName) {
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
      case 'aac':
        return 'audio/aac';
      // Video containers: an <audio>/<video>-backed player can decode and
      // play just the audio track, so these work for practice too as long
      // as the mime type actually matches the container.
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'audio/mpeg';
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practice Mode')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _fileBytes == null ? _buildUpload(context) : _buildPlayer(context),
          ),
        ),
      ),
    );
  }

  Widget _buildUpload(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.graphic_eq_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Upload any audio or video file to practice with — transpose the '
          'key, change the speed, and export the audio. Everything runs in '
          'your browser; nothing is uploaded anywhere.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isLoadingFile ? null : _pickFile,
          icon: _isLoadingFile
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded),
          label: Text(_isLoadingFile ? 'Loading…' : 'Choose file'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _duration ?? Duration.zero;
    final maxMs = duration.inMilliseconds.clamp(1, double.maxFinite.toInt()).toDouble();
    final positionMs = _position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _fileName ?? '',
          style: theme.textTheme.titleMedium,
          overflow: TextOverflow.ellipsis,
        ),
        if (_player?.videoViewType != null) ...[
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: HtmlElementView(viewType: _player!.videoViewType!),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Slider(
          value: positionMs,
          max: maxMs,
          onChanged: (v) => setState(() => _position = Duration(milliseconds: v.round())),
          onChangeEnd: (v) => _seek(Duration(milliseconds: v.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position), style: theme.textTheme.bodySmall),
              Text(_formatDuration(duration), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IconButton.filled(
          iconSize: 32,
          onPressed: _togglePlay,
          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 32,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TransposeControl(amount: _semitones, onChanged: _onTransposeChanged),
            // TransposeControl has a "Key" label above its row, which makes
            // it taller than SpeedControl on its own — give SpeedControl a
            // matching label so both stepper rows land on the same line.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Speed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                SpeedControl(
                  speed: _speed,
                  onChanged: _onSpeedChanged,
                  // Practice tools benefit from slower speeds than the main
                  // viewer's 0.5x floor allows.
                  presets: const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isExporting ? null : _download,
          icon: _isExporting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: _exportProgress,
                  ),
                )
              : const Icon(Icons.download_rounded),
          label: Text(
            _isExporting
                ? 'Exporting… ${(_exportProgress * 100).round()}%'
                : 'Download MP3',
          ),
        ),
        if (_isExporting) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(value: _exportProgress),
          ),
          const SizedBox(height: 4),
          Text(
            'Encoding takes roughly as long as the track itself — '
            'feel free to wait it out.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoadingFile ? null : _pickFile,
          child: const Text('Choose a different file'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}
