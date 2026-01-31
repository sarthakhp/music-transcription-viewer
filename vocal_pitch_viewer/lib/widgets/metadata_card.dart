import 'package:flutter/material.dart';
import '../models/pitch_data.dart';
import '../utils/music_utils.dart';

/// A card displaying pitch data metadata
class MetadataCard extends StatelessWidget {
  final ProcessedFramesData data;

  const MetadataCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final frequencyRange = data.frequencyRange;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pitch Data Info',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Metadata items in a wrap
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _buildMetaItem(
                  context,
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: data.durationFormatted,
                ),
                _buildMetaItem(
                  context,
                  icon: Icons.grid_view_rounded,
                  label: 'Frames',
                  value: '${data.frameCount.toString()} total',
                ),
                _buildMetaItem(
                  context,
                  icon: Icons.record_voice_over_rounded,
                  label: 'Voiced',
                  value: '${data.voicedFrames.length} frames',
                ),
                if (data.metadata.bpm != null)
                  _buildMetaItem(
                    context,
                    icon: Icons.speed_rounded,
                    label: 'BPM',
                    value: data.metadata.bpm!.toStringAsFixed(1),
                  ),
                _buildMetaItem(
                  context,
                  icon: Icons.graphic_eq_rounded,
                  label: 'Freq Range',
                  value: '${frequencyRange.$1.toStringAsFixed(0)} - ${frequencyRange.$2.toStringAsFixed(0)} Hz',
                ),
                _buildMetaItem(
                  context,
                  icon: Icons.music_note_rounded,
                  label: 'Note Range',
                  value: '${midiToNoteName(frequencyToMidi(frequencyRange.$1))} - ${midiToNoteName(frequencyToMidi(frequencyRange.$2))}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

