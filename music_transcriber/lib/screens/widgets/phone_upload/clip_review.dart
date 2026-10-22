import 'package:flutter/material.dart';
import '../../../services/phone_audio/audio_draft.dart';
import 'waveform_trimmer.dart';

/// Review card for the current clip: waveform with trim handles, a playhead,
/// play/pause limited to the trimmed range, and the start, length and end times.
class ClipReview extends StatelessWidget {
  final AudioDraft draft;
  const ClipReview({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([draft, draft.player]),
      builder: (context, _) {
        if (draft.duration <= 0) return const _Loading();
        final player = draft.player;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(draft.audio!.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            WaveformTrimmer(
              peaks: draft.peaks,
              duration: draft.duration,
              trimStart: draft.trimStart,
              trimEnd: draft.trimEnd,
              position: player.position,
              minSelection: AudioDraft.minSelectionSeconds,
              onTrimChanged: draft.setTrim,
              onSeek: player.seek,
            ),
            const SizedBox(height: 4),
            _times(theme, player.position),
            const SizedBox(height: 4),
            _transport(theme),
          ],
        );
      },
    );
  }

  Widget _times(ThemeData theme, double position) {
    final style = theme.textTheme.bodySmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(formatClock(draft.trimStart), style: style),
        Text('${formatClock(position)} · keeping ${formatClock(draft.trimEnd - draft.trimStart)}',
            style: style),
        Text(formatClock(draft.trimEnd), style: style),
      ],
    );
  }

  Widget _transport(ThemeData theme) {
    final player = draft.player;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: player.toggle,
          icon: Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          tooltip: player.playing ? 'Pause' : 'Play the selection',
        ),
        const SizedBox(width: 8),
        Text(
          draft.isTrimmed
              ? 'Only the selected part is transcribed'
              : 'Drag the edges to trim',
          style: theme.textTheme.bodySmall,
        ),
        const Spacer(),
        if (draft.isTrimmed)
          TextButton(
            onPressed: () => draft.setTrim(0, draft.duration),
            child: const Text('Reset'),
          ),
      ],
    );
  }
}

/// m:ss.s — tenths matter when placing a trim edge.
String formatClock(double seconds) {
  final s = seconds < 0 ? 0.0 : seconds;
  final minutes = s ~/ 60;
  final rest = (s - minutes * 60).toStringAsFixed(1).padLeft(4, '0');
  return '$minutes:$rest';
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}
