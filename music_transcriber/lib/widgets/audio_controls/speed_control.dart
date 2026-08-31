import 'package:flutter/material.dart';

/// Compact playback speed control with preset steps.
///
/// Stepper through common playback speeds (0.5x – 2.0x). Tapping the
/// speed label resets to 1.0x when active.
class SpeedControl extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;
  final List<double> presets;

  const SpeedControl({
    super.key,
    required this.speed,
    required this.onChanged,
    this.presets = const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = speed != 1.0;
    final currentIndex = presets.indexOf(speed);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_rounded, size: 16),
          onPressed: currentIndex > 0 ? () => onChanged(presets[currentIndex - 1]) : null,
          tooltip: 'Slower  [',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        _SpeedLabel(
          speed: speed,
          isActive: isActive,
          colorScheme: colorScheme,
          theme: theme,
          onTap: isActive ? () => onChanged(1.0) : null,
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded, size: 16),
          onPressed: currentIndex < presets.length - 1
              ? () => onChanged(presets[currentIndex + 1])
              : null,
          tooltip: 'Faster  ]',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}

/// Tappable speed label that highlights when speed != 1.0x.
class _SpeedLabel extends StatelessWidget {
  final double speed;
  final bool isActive;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _SpeedLabel({
    required this.speed,
    required this.isActive,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        alignment: Alignment.center,
        decoration: isActive
            ? BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          '${speed}x',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isActive ? colorScheme.onPrimaryContainer : null,
          ),
        ),
      ),
    );
  }
}
