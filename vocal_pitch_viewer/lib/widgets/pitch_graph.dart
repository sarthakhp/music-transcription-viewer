import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import '../models/instrument_data.dart';
import '../models/view_state.dart';
import 'graph_constants.dart';
import 'pitch_graph_painter.dart';
import 'playhead_painter.dart';
import '../theme/app_palette.dart';

/// Mutable holder for active note pitches shared between painters
/// Avoids widget rebuild cycle while allowing painters to communicate
class ActiveNotesHolder {
  Map<int, Color> notes = {};
}

/// Main pitch graph widget with axes and visualization.
///
/// View parameters (viewStartTime, viewEndTime, minMidi, maxMidi) are read
/// from [viewState] directly by the painters. Pan/zoom triggers a repaint
/// via the `repaint` listenable — no widget rebuild needed.
class PitchGraph extends StatefulWidget {
  final ViewState viewState;
  final ProcessedFramesData data;
  final ChordData? chordData;
  final InstrumentData? instrumentData;
  final double currentTime;
  final double referenceFrequency;
  final bool showVocals;
  final bool showBass;
  final bool showOther;
  final double vocalsMinConfidence;
  final double bassMinConfidence;
  final double otherMinConfidence;
  final int transposeAmount;
  final bool sargamEnabled;
  final int scaleRoot;
  final int vocalDetail;
  final Function(double time)? onSeek;
  final Function(double zoomDelta, double focalPointRatio)? onZoom;
  final Function(double scaleFactor)? onYZoom;
  final Function(double scrollDeltaY)? onYPan;
  final Function(double panDelta)? onPan;

  const PitchGraph({
    super.key,
    required this.viewState,
    required this.data,
    this.chordData,
    this.instrumentData,
    this.currentTime = 0,
    this.referenceFrequency = 440.0,
    this.showVocals = true,
    this.showBass = true,
    this.showOther = true,
    this.vocalsMinConfidence = 0.0,
    this.bassMinConfidence = 0.0,
    this.otherMinConfidence = 0.0,
    this.transposeAmount = 0,
    this.sargamEnabled = false,
    this.scaleRoot = 0,
    this.vocalDetail = 10,
    this.onSeek,
    this.onZoom,
    this.onYZoom,
    this.onYPan,
    this.onPan,
  });

  @override
  State<PitchGraph> createState() => _PitchGraphState();
}

class _PitchGraphState extends State<PitchGraph> {
  static const double _leftPadding = GraphConstants.leftPadding;
  static const double _rightPadding = GraphConstants.rightPadding;

  double? _hoverTime;
  double? _hoverY;
  double? _initialScale;
  bool _isDragging = false;
  double? _dragStartX;
  bool _isPinching = false;
  double _lastHorizontalScale = 1.0;
  double _lastVerticalScale = 1.0;

  // Shared mutable state for active notes - both painters reference this
  final ActiveNotesHolder _activeNotesHolder = ActiveNotesHolder();

  ViewState get _vs => widget.viewState;

  double _xToTime(double x, double width) {
    final graphWidth = width - _leftPadding - _rightPadding;
    final viewStart = _vs.viewStartTime;
    final viewEnd = _vs.viewEndTime > 0 ? _vs.viewEndTime : widget.data.maxTime;
    final ratio = (x - _leftPadding) / graphWidth;
    return viewStart + ratio * (viewEnd - viewStart);
  }

  void _handleTap(TapUpDetails details, double width) {
    if (widget.onSeek == null) return;
    final x = details.localPosition.dx;
    if (x < _leftPadding || x > width - _rightPadding) return;
    widget.onSeek!(_xToTime(x, width).clamp(0, widget.data.maxTime));
  }

  void _handleHover(PointerEvent event, double width) {
    final x = event.localPosition.dx;
    if (x < _leftPadding || x > width - _rightPadding) {
      if (_hoverTime != null) {
        setState(() { _hoverTime = null; _hoverY = null; });
      }
      return;
    }
    setState(() {
      _hoverTime = _xToTime(x, width);
      _hoverY = event.localPosition.dy;
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _initialScale = 1.0;
    _lastHorizontalScale = 1.0;
    _lastVerticalScale = 1.0;
    _isPinching = details.pointerCount >= 2;
  }

  // A two-finger touch pinch reports independent horizontal/vertical scale
  // factors (unlike a trackpad pinch, which is a single uniform PointerScaleEvent
  // handled separately below). Spreading fingers left-right zooms the time
  // (X) axis; spreading them up-down zooms the pitch (Y) axis — most graph/
  // chart apps use this mapping, and it's what lets touch users reach Y-zoom
  // without hunting for the toolbar buttons.
  void _handleScaleUpdate(ScaleUpdateDetails details, double width) {
    if (_initialScale == null) return;
    if (details.pointerCount >= 2) _isPinching = true;
    if (!_isPinching) return;

    if (details.horizontalScale != 1.0 && widget.onZoom != null) {
      final scaleFactor = details.horizontalScale / _lastHorizontalScale;
      _lastHorizontalScale = details.horizontalScale;
      if (scaleFactor != 1.0) {
        final zoomDelta = scaleFactor > 1.0 ? (scaleFactor - 1.0) : -(1.0 / scaleFactor - 1.0);
        widget.onZoom!(zoomDelta, 0.5);
      }
    }

    if (details.verticalScale != 1.0 && widget.onYZoom != null) {
      final scaleFactorY = details.verticalScale / _lastVerticalScale;
      _lastVerticalScale = details.verticalScale;
      if (scaleFactorY != 1.0) {
        widget.onYZoom!(scaleFactorY);
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _initialScale = null;
    _lastHorizontalScale = 1.0;
    _lastVerticalScale = 1.0;
    _isPinching = false;
  }

  void _handlePointerDown(PointerDownEvent event, double width) {
    if (event.buttons == 1) {
      _isDragging = true;
      _dragStartX = event.localPosition.dx;
    }
  }

  void _handlePointerMove(PointerMoveEvent event, double width) {
    if (_isDragging && _dragStartX != null && widget.onPan != null) {
      final dx = event.localPosition.dx - _dragStartX!;
      final graphWidth = width - _leftPadding - _rightPadding;
      final viewDuration = _vs.viewEndTime > 0
          ? _vs.viewEndTime - _vs.viewStartTime
          : widget.data.maxTime;
      widget.onPan!(-dx / graphWidth * viewDuration);
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

    // Get the appropriate palette based on current theme brightness
    final palette = theme.brightness == Brightness.dark
        ? indigoPalette
        : minimalistPalette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Listener(
          onPointerDown: (event) => _handlePointerDown(event, width),
          onPointerMove: (event) => _handlePointerMove(event, width),
          onPointerUp: _handlePointerUp,
          onPointerSignal: (event) {
            if (event is PointerScaleEvent && widget.onZoom != null) {
              GestureBinding.instance.pointerSignalResolver.register(event, (event) {
                final scale = (event as PointerScaleEvent).scale;
                final zoomDelta = scale > 1.0 ? (scale - 1.0) : -(1.0 / scale - 1.0);
                widget.onZoom!(zoomDelta, 0.5);
              });
            } else if (event is PointerScrollEvent) {
              final dx = event.scrollDelta.dx;
              final dy = event.scrollDelta.dy;
              if (dx != 0 || dy != 0) {
                if (_hoverTime != null) {
                  setState(() { _hoverTime = null; _hoverY = null; });
                }
                GestureBinding.instance.pointerSignalResolver.register(event, (event) {
                  final scroll = event as PointerScrollEvent;
                  if (scroll.scrollDelta.dy != 0) {
                    widget.onYPan?.call(scroll.scrollDelta.dy);
                  }
                  if (scroll.scrollDelta.dx != 0 && widget.onPan != null) {
                    final graphWidth = width - _leftPadding - _rightPadding;
                    final viewDuration = _vs.viewEndTime - _vs.viewStartTime;
                    widget.onPan!(scroll.scrollDelta.dx * viewDuration / graphWidth);
                  }
                });
              }
            }
          },
          child: MouseRegion(
            onHover: (event) => _handleHover(event, width),
            onExit: (_) => setState(() { _hoverTime = null; _hoverY = null; }),
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
                  painter: PitchGraphPainter(
                    viewState: _vs,
                    data: widget.data,
                    chordData: widget.chordData,
                    instrumentData: widget.instrumentData,
                    primaryColor: colorScheme.primary,
                    onSurfaceColor: colorScheme.onSurface,
                    gridColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    graphBgColor: palette.graphBg,
                    tonicTintColor: palette.tonicTint,
                    unvoicedColor: colorScheme.onSurface.withValues(alpha: 0.2),
                    chordColor: colorScheme.tertiary,
                    brightness: theme.brightness,
                    referenceFrequency: widget.referenceFrequency,
                    showVocals: widget.showVocals,
                    showBass: widget.showBass,
                    showOther: widget.showOther,
                    vocalsMinConfidence: widget.vocalsMinConfidence,
                    bassMinConfidence: widget.bassMinConfidence,
                    otherMinConfidence: widget.otherMinConfidence,
                    transposeAmount: widget.transposeAmount,
                    sargamEnabled: widget.sargamEnabled,
                    scaleRoot: widget.scaleRoot,
                    vocalDetail: widget.vocalDetail,
                    currentTime: widget.currentTime,
                    activeNotesHolder: _activeNotesHolder,
                  ),
                  foregroundPainter: PlayheadPainter(
                    viewState: _vs,
                    currentTime: widget.currentTime,
                    playheadColor: palette.playheadColor,
                    onSurfaceColor: colorScheme.onSurface,
                    hoverRowBgColor: palette.hoverRowBg,
                    hoverLabelColor: palette.hoverLabelColor,
                    hoverLabelBgColor: palette.hoverLabelBg,
                    tooltipBgColor: palette.tooltipBg,
                    brightness: theme.brightness,
                    hoverTime: _hoverTime,
                    hoverY: _hoverY,
                    sargamEnabled: widget.sargamEnabled,
                    scaleRoot: widget.scaleRoot,
                    activeNotesHolder: _activeNotesHolder,
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
