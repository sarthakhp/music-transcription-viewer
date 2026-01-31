import 'package:flutter/material.dart';

/// Loading overlay widget that displays when loading job data
class LoadingOverlay extends StatelessWidget {
  final bool isVisible;
  final String? message;
  final String? subtitle;

  const LoadingOverlay({
    super.key,
    required this.isVisible,
    this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message ?? 'Loading job data...',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Fetching pitch data, chords, and audio files',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

