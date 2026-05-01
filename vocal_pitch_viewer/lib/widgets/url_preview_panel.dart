import 'package:flutter/material.dart';
import '../models/job.dart';
import 'trim_range_slider.dart';

/// Preview panel shown after URL metadata is fetched.
/// Shows thumbnail, title, uploader, duration, and a trim range slider.
class UrlPreviewPanel extends StatelessWidget {
  final UrlMetadata metadata;
  final double trimStart;
  final double trimEnd;
  final ValueChanged<(double, double)> onTrimChanged;

  const UrlPreviewPanel({
    super.key,
    required this.metadata,
    required this.trimStart,
    required this.trimEnd,
    required this.onTrimChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDuration = trimEnd - trimStart;
    final maxDuration = metadata.maxDurationSeconds.toDouble();
    final isTooLong = selectedDuration > maxDuration;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: thumbnail + info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 96,
                    height: 54,
                    child: metadata.thumbnail != null
                        ? Image.network(
                            metadata.thumbnail!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, st) => _thumbnailPlaceholder(colorScheme),
                          )
                        : _thumbnailPlaceholder(colorScheme),
                  ),
                ),
                const SizedBox(width: 12),
                // Title + uploader + duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metadata.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (metadata.uploader != null) metadata.uploader!,
                          metadata.durationFormatted,
                        ].join('  ·  '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Trim slider
            TrimRangeSlider(
              totalDuration: metadata.duration,
              start: trimStart,
              end: trimEnd,
              onChanged: onTrimChanged,
            ),
            const SizedBox(height: 8),

            // Selected summary
            Row(
              children: [
                Icon(
                  isTooLong ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: isTooLong ? colorScheme.error : colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Selected: ${_formatTime(trimStart)} → ${_formatTime(trimEnd)}  (${_formatDuration(selectedDuration)})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isTooLong ? colorScheme.error : colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            if (isTooLong) ...[
              const SizedBox(height: 4),
              Text(
                'Too long (max ${metadata.maxDurationSeconds ~/ 60} min). Adjust the handles.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _thumbnailPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: colorScheme.onSurface.withValues(alpha: 0.3),
          size: 24,
        ),
      ),
    );
  }

  static String _formatTime(double seconds) {
    final total = seconds.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _formatDuration(double seconds) {
    final total = seconds.round();
    final m = total ~/ 60;
    final s = total % 60;
    if (m > 0 && s > 0) return '${m}m ${s}s';
    if (m > 0) return '${m}m';
    return '${s}s';
  }
}
