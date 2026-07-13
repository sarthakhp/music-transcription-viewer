import 'package:flutter/material.dart';

/// Zoom in/out control card showing the current view window size in seconds.
class ZoomControl extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final double viewWindowSize;

  const ZoomControl({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.viewWindowSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded, size: 20),
              onPressed: onZoomIn,
              tooltip: 'Zoom In',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out_rounded, size: 20),
              onPressed: onZoomOut,
              tooltip: 'Zoom Out',
              visualDensity: VisualDensity.compact,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${viewWindowSize.toStringAsFixed(0)}s',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
