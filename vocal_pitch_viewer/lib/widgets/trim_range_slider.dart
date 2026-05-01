import 'package:flutter/material.dart';

/// A dual-handle range slider for trimming audio.
///
/// Two draggable handles on a horizontal track. The region between handles is
/// highlighted; the region outside is dimmed. Handles cannot cross and enforce
/// a [minSelectionSeconds] minimum gap.
class TrimRangeSlider extends StatefulWidget {
  /// Total duration of the source in seconds.
  final double totalDuration;

  /// Current start position in seconds.
  final double start;

  /// Current end position in seconds.
  final double end;

  /// Minimum allowed selection in seconds.
  final double minSelectionSeconds;

  /// Called when either handle changes.
  final ValueChanged<(double start, double end)> onChanged;

  const TrimRangeSlider({
    super.key,
    required this.totalDuration,
    required this.start,
    required this.end,
    this.minSelectionSeconds = 5.0,
    required this.onChanged,
  });

  @override
  State<TrimRangeSlider> createState() => _TrimRangeSliderState();
}

class _TrimRangeSliderState extends State<TrimRangeSlider> {
  bool _draggingStart = false;
  bool _draggingEnd = false;

  static const double _handleRadius = 8.0;
  static const double _trackHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth - _handleRadius * 2;
              final startFrac = widget.start / widget.totalDuration;
              final endFrac = widget.end / widget.totalDuration;
              final startX = _handleRadius + startFrac * totalWidth;
              final endX = _handleRadius + endFrac * totalWidth;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => _onPanStart(details, startX, endX),
                onPanUpdate: (details) => _onPanUpdate(details, totalWidth),
                onPanEnd: (_) => _onPanEnd(),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 40),
                  painter: _TrimTrackPainter(
                    startX: startX,
                    endX: endX,
                    handleRadius: _handleRadius,
                    trackHeight: _trackHeight,
                    activeColor: colorScheme.primary,
                    inactiveColor: colorScheme.onSurface.withValues(alpha: 0.15),
                    handleColor: colorScheme.primary,
                    draggingStart: _draggingStart,
                    draggingEnd: _draggingEnd,
                    startLabel: _draggingStart ? _formatTime(widget.start) : null,
                    endLabel: _draggingEnd ? _formatTime(widget.end) : null,
                    labelStyle: theme.textTheme.labelSmall!.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    tooltipColor: colorScheme.primary,
                  ),
                ),
              );
            },
          ),
        ),
        // Static timestamp labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(widget.start),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _formatTime(widget.end),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onPanStart(DragStartDetails details, double startX, double endX) {
    final x = details.localPosition.dx;
    final distToStart = (x - startX).abs();
    final distToEnd = (x - endX).abs();

    // Pick the closer handle (with a tolerance zone).
    if (distToStart <= distToEnd && distToStart < 24) {
      setState(() => _draggingStart = true);
    } else if (distToEnd < 24) {
      setState(() => _draggingEnd = true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, double totalWidth) {
    if (!_draggingStart && !_draggingEnd) return;

    final dx = details.delta.dx;
    final deltaSec = (dx / totalWidth) * widget.totalDuration;

    var newStart = widget.start;
    var newEnd = widget.end;

    if (_draggingStart) {
      newStart = (widget.start + deltaSec).clamp(
        0.0,
        widget.end - widget.minSelectionSeconds,
      );
    } else if (_draggingEnd) {
      newEnd = (widget.end + deltaSec).clamp(
        widget.start + widget.minSelectionSeconds,
        widget.totalDuration,
      );
    }

    widget.onChanged((newStart, newEnd));
  }

  void _onPanEnd() {
    setState(() {
      _draggingStart = false;
      _draggingEnd = false;
    });
  }

  static String _formatTime(double seconds) {
    final total = seconds.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _TrimTrackPainter extends CustomPainter {
  final double startX;
  final double endX;
  final double handleRadius;
  final double trackHeight;
  final Color activeColor;
  final Color inactiveColor;
  final Color handleColor;
  final bool draggingStart;
  final bool draggingEnd;
  final String? startLabel;
  final String? endLabel;
  final TextStyle labelStyle;
  final Color tooltipColor;

  _TrimTrackPainter({
    required this.startX,
    required this.endX,
    required this.handleRadius,
    required this.trackHeight,
    required this.activeColor,
    required this.inactiveColor,
    required this.handleColor,
    required this.draggingStart,
    required this.draggingEnd,
    this.startLabel,
    this.endLabel,
    required this.labelStyle,
    required this.tooltipColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2 + 4; // slightly below center to leave room for tooltips
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(handleRadius, centerY - trackHeight / 2,
          size.width - handleRadius, centerY + trackHeight / 2),
      const Radius.circular(2),
    );

    // Inactive track (full).
    canvas.drawRRect(trackRect, Paint()..color = inactiveColor);

    // Active region.
    final activeRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(startX, centerY - trackHeight / 2,
          endX, centerY + trackHeight / 2),
      const Radius.circular(2),
    );
    canvas.drawRRect(activeRect, Paint()..color = activeColor.withValues(alpha: 0.7));

    // Handles.
    _drawHandle(canvas, startX, centerY, draggingStart);
    _drawHandle(canvas, endX, centerY, draggingEnd);

    // Tooltips.
    if (startLabel != null) _drawTooltip(canvas, startX, centerY, startLabel!, size);
    if (endLabel != null) _drawTooltip(canvas, endX, centerY, endLabel!, size);
  }

  void _drawHandle(Canvas canvas, double x, double y, bool isDragging) {
    final radius = isDragging ? handleRadius + 2 : handleRadius;

    // Shadow.
    canvas.drawCircle(
      Offset(x, y),
      radius + 1,
      Paint()..color = handleColor.withValues(alpha: 0.2),
    );

    // Fill.
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()..color = handleColor,
    );

    // Inner white dot.
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.4,
      Paint()..color = Colors.white,
    );
  }

  void _drawTooltip(Canvas canvas, double x, double y, String text, Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final tooltipW = tp.width + 10;
    final tooltipH = tp.height + 6;
    final tooltipX = (x - tooltipW / 2).clamp(0.0, size.width - tooltipW);
    final tooltipY = y - handleRadius - tooltipH - 6;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipX, tooltipY, tooltipW, tooltipH),
      const Radius.circular(4),
    );
    canvas.drawRRect(rrect, Paint()..color = tooltipColor);
    tp.paint(canvas, Offset(tooltipX + 5, tooltipY + 3));
  }

  @override
  bool shouldRepaint(_TrimTrackPainter old) =>
      startX != old.startX ||
      endX != old.endX ||
      draggingStart != old.draggingStart ||
      draggingEnd != old.draggingEnd;
}
