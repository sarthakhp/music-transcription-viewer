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
            Text('Time', style: theme.textTheme.labelLarge),
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
            Text('Pitch', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            BigStepper(
              value: '${viewState.yZoomScale.toStringAsFixed(1)}x',
              caption: 'vertical zoom',
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
