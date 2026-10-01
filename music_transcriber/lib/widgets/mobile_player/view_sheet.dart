import 'package:flutter/material.dart';
import '../../models/view_state.dart';
import 'sheet_scaffold.dart';

/// Bottom sheet with button alternatives to the pinch gestures: zoom the time
/// axis, zoom the pitch axis, or reset the view.
void showViewSheet({
  required BuildContext context,
  required ViewState viewState,
  required double maxTime,
}) {
  showControlSheet(
    context: context,
    title: 'Zoom',
    builder: (_) => ListenableBuilder(
      listenable: viewState,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AxisHeader(
              label: 'Time',
              showReset: viewState.viewWindowSize != ViewState.defaultWindowSize,
              onReset: () => viewState.resetTimeZoom(maxTime: maxTime),
            ),
            const SizedBox(height: 8),
            BigStepper(
              value: '${viewState.viewWindowSize.round()}s',
              caption: 'visible at once',
              decrementLabel: 'Zoom time out',
              incrementLabel: 'Zoom time in',
              onDecrement: viewState.viewWindowSize < ViewState.maxWindowSize
                  ? () => viewState.zoomOut(maxTime: maxTime)
                  : null,
              onIncrement: viewState.viewWindowSize > ViewState.minWindowSize
                  ? () => viewState.zoomIn(maxTime: maxTime)
                  : null,
            ),
            const SizedBox(height: 20),
            _AxisHeader(
              label: 'Pitch',
              showReset: viewState.yZoomScale != 1.0 || viewState.yPanOffset != 0.0,
              onReset: viewState.resetPitchZoom,
            ),
            const SizedBox(height: 8),
            BigStepper(
              value: '${(viewState.effectiveMaxMidi - viewState.effectiveMinMidi).round()}',
              caption: 'notes visible at once',
              decrementLabel: 'Zoom pitch out',
              incrementLabel: 'Zoom pitch in',
              onDecrement: viewState.yZoomScale > ViewState.minYZoomScale
                  ? () => viewState.zoomY(1 / ViewState.zoomFactor)
                  : null,
              onIncrement: viewState.yZoomScale < ViewState.maxYZoomScale
                  ? () => viewState.zoomY(ViewState.zoomFactor)
                  : null,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: viewState.resetZoom,
              icon: const Icon(Icons.fit_screen_rounded),
              label: const Text('Reset view'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: pinch the graph sideways to zoom time, up and down to zoom pitch.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        );
      },
    ),
  );
}

/// Axis title with a reset button that is hidden (but keeps its space) while
/// the axis is at its default, so the sheet never changes height.
class _AxisHeader extends StatelessWidget {
  final String label;
  final bool showReset;
  final VoidCallback onReset;

  const _AxisHeader({required this.label, required this.showReset, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Visibility(
          visible: showReset,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
      ],
    );
  }
}
