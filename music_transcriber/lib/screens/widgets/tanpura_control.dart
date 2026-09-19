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
          icon: _TanpuraIcon(color: isOn ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7)),
          isSelected: isOn,
          selectedIcon: _TanpuraIcon(color: colorScheme.primary),
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
                      _TanpuraIcon(color: colorScheme.primary, size: 16),
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
                            if (v) tanpura.start(); else tanpura.stop();
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
class _TanpuraIcon extends StatelessWidget {
  final Color color;
  final double size;
  const _TanpuraIcon({required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TanpuraPainter(color)),
    );
  }
}

class _TanpuraPainter extends CustomPainter {
  final Color color;
  _TanpuraPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Resonator body (large teardrop at bottom)
    final bodyPath = Path();
    bodyPath.addOval(Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.72),
      width: w * 0.72,
      height: h * 0.50,
    ));
    canvas.drawPath(bodyPath, paint);

    // Neck (thin rectangle)
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.42, h * 0.18, w * 0.16, h * 0.42),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(neckRect, paint);

    // Head / peg box (small oval at top)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.11), width: w * 0.28, height: h * 0.18),
      paint,
    );

    // 4 tuning pegs (tiny circles on sides of head)
    final pegR = w * 0.05;
    for (var i = 0; i < 2; i++) {
      canvas.drawCircle(Offset(w * 0.30, h * (0.07 + i * 0.08)), pegR, paint);
      canvas.drawCircle(Offset(w * 0.70, h * (0.07 + i * 0.08)), pegR, paint);
    }

    // Strings (4 thin lines from head to body)
    final stringPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = w * 0.018
      ..style = PaintingStyle.stroke;
    final offsets = [-0.09, -0.03, 0.03, 0.09];
    for (final dx in offsets) {
      canvas.drawLine(
        Offset(w * (0.5 + dx), h * 0.18),
        Offset(w * (0.5 + dx * 0.5), h * 0.80),
        stringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_TanpuraPainter old) => old.color != color;
}
