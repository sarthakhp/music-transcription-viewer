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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Root',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 28,
          child: DropdownButton<int>(
            value: scaleRoot,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            items: List.generate(
              12,
              (i) => DropdownMenuItem(value: i, child: Text(noteNames[i])),
            ),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
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
