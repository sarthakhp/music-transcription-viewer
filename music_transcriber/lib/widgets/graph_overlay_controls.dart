import 'package:flutter/material.dart';
import '../models/view_state.dart';

/// Floating controls over the bottom-right of the pitch graph: the
/// auto-scroll toggle, plus a "reset zoom" button that appears only once the
/// view has been zoomed or panned away from its default.
class GraphOverlayControls extends StatelessWidget {
  final ViewState viewState;

  /// Playhead position, read when auto-scroll is switched back on.
  final double Function() currentTime;
  final double? Function() maxTime;

  /// Larger hit areas for fingers.
  final bool touchFriendly;

  const GraphOverlayControls({
    super.key,
    required this.viewState,
    required this.currentTime,
    required this.maxTime,
    this.touchFriendly = false,
  });

  void _toggleAutoScroll() {
    final isOn = viewState.autoScroll;
    viewState.setAutoScroll(
      !isOn,
      snapToTime: isOn ? null : currentTime(),
      maxTime: maxTime(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: viewState,
      builder: (context, _) {
        final isOn = viewState.autoScroll;
        final fg = isOn
            ? scheme.onSecondaryContainer
            : scheme.onSurface.withValues(alpha: 0.7);
        final height = touchFriendly ? 44.0 : 28.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!viewState.isDefaultView) ...[
              Tooltip(
                message: 'Reset zoom',
                child: Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: viewState.resetZoom,
                    child: SizedBox(
                      width: height,
                      height: height,
                      child: Icon(Icons.fit_screen_rounded,
                          size: touchFriendly ? 22 : 16, color: scheme.onSurface),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Semantics(
              button: true,
              toggled: isOn,
              label: 'Auto-scroll',
              excludeSemantics: true,
              onTap: _toggleAutoScroll,
              child: Material(
                color: isOn
                    ? scheme.secondaryContainer.withValues(alpha: 0.9)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(height / 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(height / 2),
                  onTap: _toggleAutoScroll,
                  child: SizedBox(
                    height: height,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: touchFriendly ? 14 : 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOn ? Icons.my_location_rounded : Icons.location_searching_rounded,
                            size: touchFriendly ? 20 : 16,
                            color: fg,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            touchFriendly ? 'Follow' : 'Auto-scroll',
                            style: TextStyle(fontSize: touchFriendly ? 13 : 11, color: fg),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
