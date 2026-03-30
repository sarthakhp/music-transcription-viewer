import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import 'graph_constants.dart';
import 'pitch_graph_painter.dart';
import 'playhead_painter.dart';

/// Main pitch graph widget with axes and visualization
class PitchGraph extends StatefulWidget {
  final ProcessedFramesData data;
  final ChordData? chordData;
  final double currentTime;
  final double viewStartTime;
  final double viewEndTime;
  final double referenceFrequency;
  final double minMidi;
  final double maxMidi;
  final Function(double time)? onSeek;
  final Function(double zoomDelta, double focalPointRatio)? onZoom;
  final Function(double scaleFactor)? onYZoom;
  final Function(double scrollDeltaY)? onYPan;
  final Function(double panDelta)? onPan;
  final bool autoScroll;

  const PitchGraph({
    super.key,
    required this.data,
    this.chordData,
    this.currentTime = 0,
    this.viewStartTime = 0,
    this.viewEndTime = 0,
    this.referenceFrequency = 440.0,
    required this.minMidi,
    required this.maxMidi,
    this.onSeek,
    this.onZoom,
    this.onYZoom,
    this.onYPan,
    this.onPan,
    this.autoScroll = true,
  });

  @override
  State<PitchGraph> createState() => _PitchGraphState();
}

class _PitchGraphState extends State<PitchGraph> {
  // Layout constants from shared constants - used for hit testing
  static const double _leftPadding = GraphConstants.leftPadding;
  static const double _rightPadding = GraphConstants.rightPadding;

  // For click-to-seek
  double? _hoverTime;

  // For pinch-to-zoom
  double? _initialScale;

  // For direct mouse drag (more responsive than GestureDetector)
  bool _isDragging = false;
  double? _dragStartX;

  double _xToTime(double x, double width) {
    final graphWidth = width - _leftPadding - _rightPadding;
    final effectiveEndTime = widget.viewEndTime > 0 ? widget.viewEndTime : widget.data.maxTime;
    final ratio = (x - _leftPadding) / graphWidth;
    return widget.viewStartTime + ratio * (effectiveEndTime - widget.viewStartTime);
  }

  void _handleTap(TapUpDetails details, double width) {
    if (widget.onSeek == null) return;

    final x = details.localPosition.dx;
    if (x < _leftPadding || x > width - _rightPadding) return;

    final time = _xToTime(x, width);
    final maxTime = widget.data.maxTime;
    widget.onSeek!(time.clamp(0, maxTime));
  }

  void _handleHover(PointerEvent event, double width) {
    final x = event.localPosition.dx;
    if (x < _leftPadding || x > width - _rightPadding) {
      if (_hoverTime != null) {
        setState(() => _hoverTime = null);
      }
      return;
    }
    setState(() => _hoverTime = _xToTime(x, width));
  }

  // Track if we're in a pinch gesture (2+ fingers)
  bool _isPinching = false;
  // Track last scale to compute incremental factor each frame
  double _lastScale = 1.0;

  void _handleScaleStart(ScaleStartDetails details) {
    _initialScale = 1.0;
    _lastScale = 1.0;
    _isPinching = details.pointerCount >= 2;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, double width) {
    if (_initialScale == null) return;

    if (details.pointerCount >= 2) {
      _isPinching = true;
    }

    // Handle Y-axis semantic zoom for touch screens (multi-touch pinch)
    if (details.scale != 1.0 && _isPinching && widget.onYZoom != null) {
      final scaleFactor = details.scale / _lastScale;
      _lastScale = details.scale;
      widget.onYZoom!(scaleFactor);
    }

    // Note: Pan is handled by Listener's onPointerMove for more responsive dragging
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _initialScale = null;
    _lastScale = 1.0;
    _isPinching = false;
  }

  // Direct pointer handlers for responsive dragging
  void _handlePointerDown(PointerDownEvent event, double width) {
    // Only handle primary button (left click / single touch)
    if (event.buttons == 1) {
      _isDragging = true;
      _dragStartX = event.localPosition.dx;
    }
  }

  void _handlePointerMove(PointerMoveEvent event, double width) {
    if (_isDragging && _dragStartX != null && widget.onPan != null) {
      final dx = event.localPosition.dx - _dragStartX!;
      final graphWidth = width - _leftPadding - _rightPadding;
      final viewDuration = widget.viewEndTime > 0
          ? widget.viewEndTime - widget.viewStartTime
          : widget.data.maxTime;
      final timeDelta = -dx / graphWidth * viewDuration;
      widget.onPan!(timeDelta);
      _dragStartX = event.localPosition.dx;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _isDragging = false;
    _dragStartX = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveEndTime = widget.viewEndTime > 0 ? widget.viewEndTime : widget.data.maxTime;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Listener(
          onPointerDown: (event) => _handlePointerDown(event, width),
          onPointerMove: (event) => _handlePointerMove(event, width),
          onPointerUp: _handlePointerUp,
          onPointerSignal: (event) {
            if (event is PointerScaleEvent && widget.onYZoom != null) {
              GestureBinding.instance.pointerSignalResolver.register(event, (event) {
                widget.onYZoom!((event as PointerScaleEvent).scale);
              });
            } else if (event is PointerScrollEvent) {
              final dx = event.scrollDelta.dx;
              final dy = event.scrollDelta.dy;
              if (dx != 0 || dy != 0) {
                GestureBinding.instance.pointerSignalResolver.register(event, (event) {
                  final scroll = event as PointerScrollEvent;
                  if (scroll.scrollDelta.dy != 0) {
                    widget.onYPan?.call(scroll.scrollDelta.dy);
                  }
                  if (scroll.scrollDelta.dx != 0 && widget.onPan != null) {
                    final graphWidth = width - _leftPadding - _rightPadding;
                    final viewDuration = widget.viewEndTime - widget.viewStartTime;
                    final timeDelta = scroll.scrollDelta.dx * viewDuration / graphWidth;
                    widget.onPan!(timeDelta);
                  }
                });
              }
            }
          },
          child: MouseRegion(
            onHover: (event) => _handleHover(event, width),
            onExit: (_) => setState(() => _hoverTime = null),
            cursor: widget.onSeek != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
            child: GestureDetector(
              onTapUp: (details) => _handleTap(details, width),
              onScaleStart: _handleScaleStart,
              onScaleUpdate: (details) => _handleScaleUpdate(details, width),
              onScaleEnd: _handleScaleEnd,
              child: Container(
                color: colorScheme.surface,
                child: CustomPaint(
                  size: Size(width, height),
                  // Static layer: pitch points, grid, axes, chords
                  painter: PitchGraphPainter(
                    data: widget.data,
                    chordData: widget.chordData,
                    viewStartTime: widget.viewStartTime,
                    viewEndTime: effectiveEndTime,
                    primaryColor: colorScheme.primary,
                    onSurfaceColor: colorScheme.onSurface,
                    gridColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    unvoicedColor: colorScheme.onSurface.withValues(alpha: 0.2),
                    chordColor: colorScheme.tertiary,
                    brightness: theme.brightness,
                    referenceFrequency: widget.referenceFrequency,
                    minMidi: widget.minMidi,
                    maxMidi: widget.maxMidi,
                  ),
                  // Dynamic layer: playhead only (repaints frequently)
                  foregroundPainter: PlayheadPainter(
                    currentTime: widget.currentTime,
                    viewStartTime: widget.viewStartTime,
                    viewEndTime: effectiveEndTime,
                    playheadColor: Colors.red,
                    onSurfaceColor: colorScheme.onSurface,
                    brightness: theme.brightness,
                    hoverTime: _hoverTime,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
