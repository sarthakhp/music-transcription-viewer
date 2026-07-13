import 'package:flutter/material.dart';
import '../../utils/music_utils.dart';

/// Seek slider showing current time / duration with formatted labels.
class SeekSlider extends StatelessWidget {
  final double currentTime;
  final double duration;
  final ValueChanged<double> onSeek;

  const SeekSlider({
    super.key,
    required this.currentTime,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = currentTime.clamp(0.0, duration > 0 ? duration : 1.0);
    final max = duration > 0 ? duration : 1.0;

    return Row(
      children: [
        _TimeLabel(text: formatTime(currentTime), theme: theme),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: clamped,
              min: 0,
              max: max,
              onChanged: duration > 0 ? onSeek : null,
            ),
          ),
        ),
        _TimeLabel(text: formatTime(duration), theme: theme),
      ],
    );
  }
}

/// Monospace tabular time label (e.g. "1:23").
class _TimeLabel extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _TimeLabel({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Primary transport buttons: stop, play/pause, back/forward seek.
class TransportButtons extends StatelessWidget {
  static const double seekStepSeconds = 1;

  final bool isPlaying;
  final double currentTime;
  final double duration;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<double> onSeek;
  final MainAxisAlignment alignment;

  const TransportButtons({
    super.key,
    required this.isPlaying,
    required this.currentTime,
    required this.duration,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        IconButton(
          icon: const Icon(Icons.replay_rounded),
          onPressed: () => onSeek((currentTime - seekStepSeconds).clamp(0, duration)),
          tooltip: 'Back ${seekStepSeconds.toInt()}s',
        ),
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
          icon: Transform.flip(flipX: true, child: const Icon(Icons.replay_rounded)),
          onPressed: () => onSeek((currentTime + seekStepSeconds).clamp(0, duration)),
          tooltip: 'Forward ${seekStepSeconds.toInt()}s',
        ),
      ],
    );
  }
}
