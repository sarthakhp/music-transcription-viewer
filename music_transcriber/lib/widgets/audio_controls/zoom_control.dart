import 'package:flutter/material.dart';

/// Zoom out / value / zoom in for one axis. Used twice in the player bar:
/// "Time zoom" (seconds visible) and "Pitch zoom" (vertical magnification),
/// so each readout matches exactly what its buttons change.
class ZoomControl extends StatelessWidget {
  final String value;
  final String axisName;

  /// Width reserved for the value so the buttons don't move as it changes.
  final double valueWidth;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const ZoomControl({
    super.key,
    required this.value,
    required this.axisName,
    this.valueWidth = 48,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget button(IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.zoom_out_rounded, 'Zoom $axisName out', onZoomOut),
        SizedBox(
          width: valueWidth,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        button(Icons.zoom_in_rounded, 'Zoom $axisName in', onZoomIn),
      ],
    );
  }
}
