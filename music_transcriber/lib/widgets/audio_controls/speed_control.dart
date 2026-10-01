import 'package:flutter/material.dart';

/// Playback speed as one-click preset chips (the selected one is filled).
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

  static String format(double v) => v == v.roundToDouble() ? '${v.toInt()}x' : '${v}x';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in presets)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Tooltip(
              message: 'Play at ${format(p)}',
              child: Material(
                color: p == speed ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(p),
                  child: Container(
                    height: 32,
                    constraints: const BoxConstraints(minWidth: 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      format(p),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: p == speed ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
