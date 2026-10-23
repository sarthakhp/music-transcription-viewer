import 'package:flutter/material.dart';
import 'waveform_painter.dart';

/// Waveform with two draggable trim handles and a playhead. Dragging near a
/// handle moves it; dragging elsewhere (or tapping) scrubs the playhead.
class WaveformTrimmer extends StatefulWidget {
  final List<double>? peaks;
  final double duration;
  final double trimStart;
  final double trimEnd;
  final double position;
  final double minSelection;
  final void Function(double start, double end) onTrimChanged;
  final ValueChanged<double> onSeek;

  const WaveformTrimmer({
    super.key,
    required this.peaks,
    required this.duration,
    required this.trimStart,
    required this.trimEnd,
    required this.position,
    required this.minSelection,
    required this.onTrimChanged,
    required this.onSeek,
  });

  @override
  State<WaveformTrimmer> createState() => _WaveformTrimmerState();
}

enum _Drag { none, start, end, scrub }

class _WaveformTrimmerState extends State<WaveformTrimmer> {
  static const _grabDistance = 28.0;
  _Drag _drag = _Drag.none;

  double _toSeconds(double dx, double width) =>
      (dx / width).clamp(0.0, 1.0) * widget.duration;

  _Drag _hitTest(double dx, double width) {
    final toStart = (dx - widget.trimStart / widget.duration * width).abs();
    final toEnd = (dx - widget.trimEnd / widget.duration * width).abs();
    if (toStart > _grabDistance && toEnd > _grabDistance) return _Drag.scrub;
    return toStart <= toEnd ? _Drag.start : _Drag.end;
  }

  void _apply(double dx, double width) {
    final seconds = _toSeconds(dx, width);
    switch (_drag) {
      case _Drag.start:
        widget.onTrimChanged(
          seconds.clamp(0.0, widget.trimEnd - widget.minSelection),
          widget.trimEnd,
        );
      case _Drag.end:
        widget.onTrimChanged(
          widget.trimStart,
          seconds.clamp(widget.trimStart + widget.minSelection, widget.duration),
        );
      case _Drag.scrub:
        widget.onSeek(seconds.clamp(widget.trimStart, widget.trimEnd));
      case _Drag.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.duration <= 0 ? 1.0 : widget.duration;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => widget.onSeek(
              _toSeconds(d.localPosition.dx, width).clamp(widget.trimStart, widget.trimEnd)),
          onHorizontalDragStart: (d) {
            _drag = _hitTest(d.localPosition.dx, width);
            _apply(d.localPosition.dx, width);
          },
          onHorizontalDragUpdate: (d) => _apply(d.localPosition.dx, width),
          onHorizontalDragEnd: (_) => _drag = _Drag.none,
          child: SizedBox(
            height: 88,
            width: width,
            child: CustomPaint(
              painter: WaveformPainter(
                peaks: widget.peaks,
                trimStart: widget.trimStart / total,
                trimEnd: widget.trimEnd / total,
                playhead: (widget.position / total).clamp(0.0, 1.0),
                active: scheme.primary,
                dimmed: scheme.onSurface.withValues(alpha: 0.18),
                handle: scheme.primary,
                playheadColor: scheme.error,
              ),
            ),
          ),
        );
      },
    );
  }
}
