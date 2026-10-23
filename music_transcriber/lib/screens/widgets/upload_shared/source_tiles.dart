import 'package:flutter/material.dart';
import 'source_selector.dart';

/// The starting point of adding a song: three big, obvious ways in. Choosing
/// one opens just that step, so nothing else is on screen until it is needed.
class SourceTiles extends StatelessWidget {
  final bool enabled;
  final ValueChanged<UploadSource> onPick;

  const SourceTiles({super.key, required this.enabled, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tile(context, UploadSource.file, Icons.audio_file_rounded, 'Upload file'),
        const SizedBox(width: 10),
        _tile(context, UploadSource.record, Icons.mic_rounded, 'Record'),
        const SizedBox(width: 10),
        _tile(context, UploadSource.link, Icons.link_rounded, 'Paste link'),
      ],
    );
  }

  Widget _tile(BuildContext context, UploadSource source, IconData icon, String label) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? () => onPick(source) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(icon, size: 28, color: colors.primary),
                const SizedBox(height: 8),
                Text(label, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top of the "add this song" step: where it comes from, and a way back.
class ComposeHeader extends StatelessWidget {
  final String title;
  final bool enabled;
  final VoidCallback onBack;

  const ComposeHeader({super.key, required this.title, required this.enabled, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: enabled ? onBack : null,
          visualDensity: VisualDensity.compact,
        ),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
