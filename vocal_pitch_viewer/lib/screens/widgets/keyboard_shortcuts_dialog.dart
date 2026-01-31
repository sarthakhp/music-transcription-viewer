import 'package:flutter/material.dart';

/// Dialog that displays keyboard shortcuts
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.keyboard_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Keyboard Shortcuts'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildShortcutRow(context, 'Space', 'Play / Pause'),
          _buildShortcutRow(context, '←', 'Seek back 5s'),
          _buildShortcutRow(context, '→', 'Seek forward 5s'),
          _buildShortcutRow(context, '+', 'Zoom in'),
          _buildShortcutRow(context, '-', 'Zoom out'),
          _buildShortcutRow(context, '0', 'Reset zoom'),
          _buildShortcutRow(context, 'M', 'Mute / Unmute'),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    );
  }

  Widget _buildShortcutRow(BuildContext context, String key, String description) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              key,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  /// Show the keyboard shortcuts dialog
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const KeyboardShortcutsDialog(),
    );
  }
}

