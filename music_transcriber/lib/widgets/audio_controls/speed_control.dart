import 'package:flutter/material.dart';

/// Compact playback-speed stepper: `− 1x +` steps through the presets, and
/// tapping the value opens a menu to jump straight to any of them.
class SpeedControl extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;
  final List<double> presets;

  const SpeedControl({
    super.key,
    required this.speed,
    required this.onChanged,
    this.presets = const [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
  });

  static String format(double v) => v == v.roundToDouble() ? '${v.toInt()}x' : '${v}x';

  /// Index of the preset closest to [speed] (exact match in practice).
  int get _index {
    var best = 0;
    for (var i = 1; i < presets.length; i++) {
      if ((presets[i] - speed).abs() < (presets[best] - speed).abs()) best = i;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = _index;

    Widget stepButton(IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
          icon: Icon(icon, size: 18),
          onPressed: onPressed,
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        stepButton(Icons.remove_rounded, 'Slower ([)',
            index > 0 ? () => onChanged(presets[index - 1]) : null),
        PopupMenuButton<double>(
          tooltip: 'Choose speed (\\ resets to 1x)',
          initialValue: presets[index],
          onSelected: onChanged,
          position: PopupMenuPosition.under,
          itemBuilder: (_) => [
            for (final p in presets)
              PopupMenuItem(value: p, child: Text(format(p))),
          ],
          child: Container(
            width: 52,
            height: 32,
            alignment: Alignment.center,
            child: Text(
              format(speed),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        stepButton(Icons.add_rounded, 'Faster (])',
            index < presets.length - 1 ? () => onChanged(presets[index + 1]) : null),
      ],
    );
  }
}
