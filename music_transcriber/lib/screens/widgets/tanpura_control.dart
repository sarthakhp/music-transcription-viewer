import 'package:flutter/material.dart';
import '../../services/tanpura_service.dart';

/// App-bar button that toggles the tanpura drone and shows a volume popover.
class TanpuraButton extends StatefulWidget {
  final TanpuraService tanpura;

  /// Called right before the drone starts, so it can be tuned to whatever
  /// the current scale root is at that moment rather than a stale value.
  final VoidCallback? onBeforeStart;

  const TanpuraButton({super.key, required this.tanpura, this.onBeforeStart});

  @override
  State<TanpuraButton> createState() => _TanpuraButtonState();
}

class _TanpuraButtonState extends State<TanpuraButton> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    widget.tanpura.addListener(_onTanpuraChanged);
  }

  @override
  void dispose() {
    widget.tanpura.removeListener(_onTanpuraChanged);
    _closeOverlay();
    super.dispose();
  }

  void _onTanpuraChanged() => setState(() {});

  void _toggleOverlay() {
    if (_overlay != null) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(builder: (_) => _TanpuraPopover(
      layerLink: _layerLink,
      tanpura: widget.tanpura,
      onClose: _closeOverlay,
      onBeforeStart: widget.onBeforeStart,
    ));
    overlay.insert(_overlay!);
    setState(() {});
  }

  void _closeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final isOn = widget.tanpura.isPlaying;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: isOn ? 'Tanpura on — tap to adjust (T to stop)' : 'Start tanpura drone (T)',
        child: IconButton(
          icon: _TanpuraIcon(opacity: isOn ? 1.0 : 0.6),
          isSelected: isOn,
          selectedIcon: const _TanpuraIcon(),
          onPressed: () {
            if (!widget.tanpura.isPlaying) {
              widget.onBeforeStart?.call();
              widget.tanpura.start();
            }
            _toggleOverlay();
          },
        ),
      ),
    );
  }
}

class _TanpuraPopover extends StatefulWidget {
  final LayerLink layerLink;
  final TanpuraService tanpura;
  final VoidCallback onClose;
  final VoidCallback? onBeforeStart;

  const _TanpuraPopover({
    required this.layerLink,
    required this.tanpura,
    required this.onClose,
    this.onBeforeStart,
  });

  @override
  State<_TanpuraPopover> createState() => _TanpuraPopoverState();
}

class _TanpuraPopoverState extends State<_TanpuraPopover> {
  @override
  void initState() {
    super.initState();
    widget.tanpura.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.tanpura.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tanpura = widget.tanpura;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        // Tap outside to close
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onClose,
          ),
        ),
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-120, 48),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surface,
            child: Container(
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _TanpuraIcon(size: 22),
                      const SizedBox(width: 8),
                      Text('Tanpura', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      if (tanpura.isLoading)
                        const SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Switch(
                          value: tanpura.isPlaying,
                          onChanged: (v) {
                            if (v) {
                              widget.onBeforeStart?.call();
                              tanpura.start();
                            } else {
                              tanpura.stop();
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.volume_down_rounded, size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      Expanded(
                        child: Slider(
                          value: tanpura.volume,
                          min: 0,
                          max: 1,
                          onChanged: tanpura.setVolume,
                        ),
                      ),
                      Icon(Icons.volume_up_rounded, size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    ],
                  ),
                  Text(
                    'Tuned to current key',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tanpura silhouette icon drawn with CustomPaint.
/// Tanpura glyph rendered from a transparent-background PNG. `opacity` is
/// used instead of a color tint (the source image has its own fixed colors)
/// to distinguish the on/off state.
class _TanpuraIcon extends StatelessWidget {
  final double opacity;
  final double size;
  const _TanpuraIcon({this.opacity = 1.0, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        'assets/images/tanpura.png',
        width: size,
        height: size,
      ),
    );
  }
}
