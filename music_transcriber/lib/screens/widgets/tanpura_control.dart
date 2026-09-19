import 'package:flutter/material.dart';
import '../../services/tanpura_service.dart';

/// App-bar button that toggles the tanpura drone and shows a volume popover.
class TanpuraButton extends StatefulWidget {
  final TanpuraService tanpura;

  const TanpuraButton({super.key, required this.tanpura});

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
    ));
    overlay.insert(_overlay!);
    setState(() {});
  }

  void _closeOverlay() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isOn = widget.tanpura.isPlaying;
    final colorScheme = Theme.of(context).colorScheme;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: isOn ? 'Tanpura on — tap to adjust' : 'Start tanpura drone',
        child: IconButton(
          icon: const Icon(Icons.music_note),
          isSelected: isOn,
          selectedIcon: const Icon(Icons.music_note),
          color: isOn ? colorScheme.primary : null,
          onPressed: () {
            if (!widget.tanpura.isPlaying) {
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

  const _TanpuraPopover({
    required this.layerLink,
    required this.tanpura,
    required this.onClose,
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
                      Icon(Icons.music_note, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Tanpura', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      Switch(
                        value: tanpura.isPlaying,
                        onChanged: (v) {
                          if (v) {
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
