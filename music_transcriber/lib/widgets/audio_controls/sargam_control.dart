import 'package:flutter/material.dart';
import '../../utils/music_utils.dart';

/// Sargam notation toggle with an adjacent scale-root selector.
///
/// The "Sa Re Ga" pill toggles between Western and Sargam notation; the
/// dropdown picks the scale root (0–11) used by [midiToSargam].
class SargamControl extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggled;
  final int scaleRoot;
  final ValueChanged<int> onScaleRootChanged;

  const SargamControl({
    super.key,
    required this.enabled,
    required this.onToggled,
    required this.scaleRoot,
    required this.onScaleRootChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScaleRootPicker(
          scaleRoot: scaleRoot,
          onChanged: onScaleRootChanged,
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(width: 8),
        _SargamToggle(
          enabled: enabled,
          onToggled: onToggled,
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

/// Vertical scale-root dropdown (labeled "Root").
class _ScaleRootPicker extends StatelessWidget {
  final int scaleRoot;
  final ValueChanged<int> onChanged;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _ScaleRootPicker({
    required this.scaleRoot,
    required this.onChanged,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // A 4x3 grid of notes in a small popup under the button; a long vertical
    // dropdown would cover the graph.
    return PopupMenuButton<int>(
      tooltip: 'Root note',
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<int>(
          enabled: false,
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 4 * 44.0 + 3 * 6,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < 12; i++)
                  _RootNoteChip(
                    label: noteNames[i],
                    selected: i == scaleRoot,
                    colorScheme: colorScheme,
                    onTap: () => Navigator.pop(context, i),
                  ),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 8, right: 2),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              noteNames[scaleRoot % 12],
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _RootNoteChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _RootNoteChip({
    required this.label,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 36,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Sa Re Ga" toggle pill.
class _SargamToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggled;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _SargamToggle({
    required this.enabled,
    required this.onToggled,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? 'Switch to Western notation' : 'Switch to Sargam notation',
      child: InkWell(
        onTap: () => onToggled(!enabled),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: enabled ? colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(4),
            border: enabled
                ? null
                : Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Sa Re Ga',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: enabled
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
