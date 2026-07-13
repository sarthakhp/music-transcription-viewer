import 'package:flutter/material.dart';
import 'audio_controls/playback_controls.dart';
import 'audio_controls/zoom_control.dart';
import 'audio_controls/speed_control.dart';
import 'audio_controls/transpose_control.dart';
import 'audio_controls/sargam_control.dart';
import 'audio_controls/reference_frequency_control.dart';

/// Audio playback controls widget.
///
/// Composes [SeekSlider] + transport/secondary controls, switching between
/// a single-row "wide" layout and a stacked "narrow" layout at <700px width.
/// Sub-controls live in `audio_controls/` for maintainability.
class AudioControls extends StatelessWidget {
  static const double seekStepSeconds = TransportButtons.seekStepSeconds;
  final bool isPlaying;
  final double currentTime;
  final double duration;
  final double referenceFrequency;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onReferenceFrequencyChange;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final double viewWindowSize;
  final int transposeAmount;
  final ValueChanged<int> onTransposeChanged;
  final double playbackSpeed;
  final ValueChanged<double> onSpeedChanged;
  final bool sargamEnabled;
  final ValueChanged<bool> onSargamToggled;
  final int scaleRoot;
  final ValueChanged<int> onScaleRootChanged;

  const AudioControls({
    super.key,
    required this.isPlaying,
    required this.currentTime,
    required this.duration,
    required this.referenceFrequency,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
    required this.onReferenceFrequencyChange,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.viewWindowSize,
    required this.transposeAmount,
    required this.onTransposeChanged,
    required this.playbackSpeed,
    required this.onSpeedChanged,
    required this.sargamEnabled,
    required this.onSargamToggled,
    required this.scaleRoot,
    required this.onScaleRootChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.sizeOf(context).width < 700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SeekSlider(
            currentTime: currentTime,
            duration: duration,
            onSeek: onSeek,
          ),
          const SizedBox(height: 8),
          if (isNarrow) _buildNarrowControls() else _buildWideControls(),
        ],
      ),
    );
  }

  /// Original single-row layout — unchanged for desktop/tablet widths.
  Widget _buildWideControls() {
    return Row(
      children: [
        ZoomControl(
          onZoomIn: onZoomIn,
          onZoomOut: onZoomOut,
          viewWindowSize: viewWindowSize,
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.stop_rounded),
          onPressed: onStop,
          tooltip: 'Stop',
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onPlayPause,
          icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          label: Text(isPlaying ? 'Pause' : 'Play'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.replay_rounded),
          onPressed: () => onSeek((currentTime - seekStepSeconds).clamp(0, duration)),
          tooltip: 'Back ${seekStepSeconds.toInt()}s',
        ),
        IconButton(
          icon: Transform.flip(flipX: true, child: const Icon(Icons.replay_rounded)),
          onPressed: () => onSeek((currentTime + seekStepSeconds).clamp(0, duration)),
          tooltip: 'Forward ${seekStepSeconds.toInt()}s',
        ),
        const SizedBox(width: 16),
        SpeedControl(speed: playbackSpeed, onChanged: onSpeedChanged),
        const SizedBox(width: 16),
        TransposeControl(amount: transposeAmount, onChanged: onTransposeChanged),
        const SizedBox(width: 16),
        SargamControl(
          enabled: sargamEnabled,
          onToggled: onSargamToggled,
          scaleRoot: scaleRoot,
          onScaleRootChanged: onScaleRootChanged,
        ),
        const Spacer(),
        ReferenceFrequencyControl(
          frequency: referenceFrequency,
          onChanged: onReferenceFrequencyChange,
        ),
      ],
    );
  }

  /// Narrow layout: primary transport controls stay centered and always
  /// visible; secondary controls (zoom/speed/transpose/sargam/reference
  /// frequency) move into a horizontally-scrollable row so nothing overflows
  /// regardless of how many of them are on screen.
  Widget _buildNarrowControls() {
    return Column(
      children: [
        TransportButtons(
          isPlaying: isPlaying,
          currentTime: currentTime,
          duration: duration,
          onPlayPause: onPlayPause,
          onStop: onStop,
          onSeek: onSeek,
          alignment: MainAxisAlignment.center,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ZoomControl(
                onZoomIn: onZoomIn,
                onZoomOut: onZoomOut,
                viewWindowSize: viewWindowSize,
              ),
              const SizedBox(width: 12),
              SpeedControl(speed: playbackSpeed, onChanged: onSpeedChanged),
              const SizedBox(width: 16),
              TransposeControl(amount: transposeAmount, onChanged: onTransposeChanged),
              const SizedBox(width: 16),
              SargamControl(
                enabled: sargamEnabled,
                onToggled: onSargamToggled,
                scaleRoot: scaleRoot,
                onScaleRootChanged: onScaleRootChanged,
              ),
              const SizedBox(width: 16),
              ReferenceFrequencyControl(
                frequency: referenceFrequency,
                onChanged: onReferenceFrequencyChange,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
