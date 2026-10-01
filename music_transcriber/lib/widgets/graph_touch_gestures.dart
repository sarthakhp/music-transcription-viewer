import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/view_state.dart';

/// Which axes a two-finger pinch is currently zooming.
enum PinchAxis { undecided, horizontal, vertical, both }

/// Decides which axis a pinch zooms, from how the finger spans change.
///
/// Fingers spreading mostly left/right zoom time, mostly up/down zoom pitch,
/// and a diagonal pinch zooms both (the same convention as charts and maps).
/// The choice is made once the fingers have moved enough to tell, then stays
/// fixed for the rest of the gesture so the zoom never flips axis mid-pinch.
class PinchAxisResolver {
  /// Total span change (px) needed before an axis is chosen.
  static const double decisionThreshold = 10;

  /// One axis wins only if its change is at least this many times the other's;
  /// anything closer counts as a diagonal pinch.
  static const double dominanceRatio = 2.0;

  PinchAxis axis = PinchAxis.undecided;

  /// [dxChange]/[dyChange] are the absolute changes of the finger span on each
  /// axis since the pinch began.
  PinchAxis update(double dxChange, double dyChange) {
    if (axis != PinchAxis.undecided) return axis;
    final ax = dxChange.abs();
    final ay = dyChange.abs();
    if (math.max(ax, ay) < decisionThreshold) return axis;
    if (ax >= ay * dominanceRatio) {
      axis = PinchAxis.horizontal;
    } else if (ay >= ax * dominanceRatio) {
      axis = PinchAxis.vertical;
    } else {
      axis = PinchAxis.both;
    }
    return axis;
  }

  void reset() => axis = PinchAxis.undecided;
}

/// Touch pan / pinch / fling for the pitch graph.
///
/// * One finger drags the view on both axes (locks to one axis when the drag
///   is clearly straight) and flings with momentum on release.
/// * Two fingers pinch-zoom the axis they spread along (see
///   [PinchAxisResolver]), anchored under the fingers, and also pan with the
///   midpoint.
///
/// Mouse and trackpad input are not handled here; only touch and stylus.
class TouchGraphGestures {
  TouchGraphGestures({
    required TickerProvider vsync,
    required this.viewState,
    required this.maxTime,
    required this.graphRect,
  }) {
    _flingTicker = vsync.createTicker(_onFlingTick);
  }

  final ViewState viewState;

  /// Song length in seconds (read lazily; data can change under us).
  final double Function() maxTime;

  /// Current plot rectangle in the graph widget's local coordinates.
  final Rect Function() graphRect;

  /// Movement before a one-finger touch becomes a drag rather than a tap.
  static const double _dragSlop = 6;

  /// Finger spans below this are clamped so a near-zero span can't make the
  /// zoom factor explode.
  static const double _minSpan = 40;

  /// Release speed (px/s) below which no fling starts.
  static const double _minFlingSpeed = 120;

  final Map<int, Offset> _pointers = {};
  final VelocityTracker _velocity = VelocityTracker.withKind(PointerDeviceKind.touch);
  final PinchAxisResolver _resolver = PinchAxisResolver();
  late final Ticker _flingTicker;

  Offset? _lastPanPosition;
  Offset _dragTravel = Offset.zero;
  bool _dragging = false;
  bool _lockX = false;
  bool _lockY = false;

  Offset? _pinchStartSpan;
  Offset? _lastPinchSpan;
  Offset? _lastPinchMid;

  Simulation? _flingX;
  Simulation? _flingY;
  double _flingLastX = 0;
  double _flingLastY = 0;

  /// True once a second finger touched during the current gesture. The tap
  /// recognizer can still fire when the last finger lifts; callers use this to
  /// ignore that tap instead of seeking.
  bool multiTouchSeen = false;

  static bool _isTouch(PointerEvent e) =>
      e.kind == PointerDeviceKind.touch || e.kind == PointerDeviceKind.stylus;

  void onPointerDown(PointerDownEvent e) {
    if (!_isTouch(e)) return;
    _stopFling();
    if (_pointers.isEmpty) {
      multiTouchSeen = false;
      _velocity.addPosition(e.timeStamp, e.localPosition);
    }
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _beginDrag(e.localPosition);
    } else if (_pointers.length == 2) {
      multiTouchSeen = true;
      _beginPinch();
    }
  }

  void onPointerMove(PointerMoveEvent e) {
    if (!_isTouch(e) || !_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _velocity.addPosition(e.timeStamp, e.localPosition);
      _updateDrag(e.localPosition);
    } else if (_pointers.length == 2) {
      _updatePinch();
    }
  }

  void onPointerUp(PointerEvent e) {
    if (!_isTouch(e) || !_pointers.containsKey(e.pointer)) return;
    final wasSingle = _pointers.length == 1;
    if (wasSingle && _dragging && e is PointerUpEvent) {
      _velocity.addPosition(e.timeStamp, e.localPosition);
      _startFling(_velocity.getVelocity().pixelsPerSecond);
    }
    _pointers.remove(e.pointer);
    if (_pointers.length == 1) {
      // Pinch -> drag handover: continue panning from the remaining finger
      // without a jump.
      _resolver.reset();
      _pinchStartSpan = null;
      _beginDrag(_pointers.values.first, alreadyMoving: true);
    } else if (_pointers.isEmpty) {
      _endGesture();
    }
  }

  void dispose() {
    _flingTicker.dispose();
  }

  // --- Drag -----------------------------------------------------------------

  void _beginDrag(Offset position, {bool alreadyMoving = false}) {
    _lastPanPosition = position;
    _dragTravel = Offset.zero;
    _dragging = alreadyMoving;
    _lockX = false;
    _lockY = false;
  }

  void _updateDrag(Offset position) {
    final last = _lastPanPosition;
    if (last == null) return;
    var delta = position - last;
    _lastPanPosition = position;
    _dragTravel += delta;

    if (!_dragging) {
      if (_dragTravel.distance < _dragSlop) return;
      _dragging = true;
      // Straight-ish drags stick to one axis so a horizontal scrub doesn't
      // wobble vertically (and vice versa); diagonal drags stay free.
      final ax = _dragTravel.dx.abs();
      final ay = _dragTravel.dy.abs();
      _lockX = ax > ay * 2;
      _lockY = ay > ax * 2;
      delta = _dragTravel;
    }
    if (_lockX) delta = Offset(delta.dx, 0);
    if (_lockY) delta = Offset(0, delta.dy);
    _panBy(delta);
  }

  void _panBy(Offset delta) {
    final rect = graphRect();
    if (delta.dx != 0 && rect.width > 0) {
      viewState.panX(-delta.dx / rect.width * viewState.viewWindowSize,
          maxTime: maxTime());
    }
    if (delta.dy != 0 && rect.height > 0) {
      viewState.panYByFraction(delta.dy / rect.height);
    }
  }

  // --- Fling ----------------------------------------------------------------

  void _startFling(Offset velocity) {
    if (velocity.distance < _minFlingSpeed) return;
    final vx = _lockY ? 0.0 : velocity.dx;
    final vy = _lockX ? 0.0 : velocity.dy;
    _flingX = vx.abs() > _minFlingSpeed
        ? ClampingScrollSimulation(position: 0, velocity: vx)
        : null;
    _flingY = vy.abs() > _minFlingSpeed
        ? ClampingScrollSimulation(position: 0, velocity: vy)
        : null;
    if (_flingX == null && _flingY == null) return;
    _flingLastX = 0;
    _flingLastY = 0;
    _flingTicker.start();
  }

  void _onFlingTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final x = _flingX?.x(t) ?? _flingLastX;
    final y = _flingY?.x(t) ?? _flingLastY;
    _panBy(Offset(x - _flingLastX, y - _flingLastY));
    _flingLastX = x;
    _flingLastY = y;
    final doneX = _flingX?.isDone(t) ?? true;
    final doneY = _flingY?.isDone(t) ?? true;
    if (doneX && doneY) _stopFling();
  }

  void _stopFling() {
    if (_flingTicker.isActive) _flingTicker.stop();
    _flingX = null;
    _flingY = null;
  }

  // --- Pinch ----------------------------------------------------------------

  Offset get _span {
    final pts = _pointers.values.toList();
    final d = pts[0] - pts[1];
    return Offset(d.dx.abs(), d.dy.abs());
  }

  Offset get _midpoint {
    final pts = _pointers.values.toList();
    return (pts[0] + pts[1]) / 2;
  }

  void _beginPinch() {
    _resolver.reset();
    _dragging = true; // never treat the lift as a tap
    _pinchStartSpan = _span;
    _lastPinchSpan = _pinchStartSpan;
    _lastPinchMid = _midpoint;
  }

  void _updatePinch() {
    final start = _pinchStartSpan;
    final lastSpan = _lastPinchSpan;
    final lastMid = _lastPinchMid;
    if (start == null || lastSpan == null || lastMid == null) return;

    final span = _span;
    final mid = _midpoint;
    final axis = _resolver.update(span.dx - start.dx, span.dy - start.dy);
    final rect = graphRect();

    // Two-finger drag pans the view with the midpoint.
    _panBy(mid - lastMid);

    if (axis == PinchAxis.horizontal || axis == PinchAxis.both) {
      final factor = math.max(span.dx, _minSpan) / math.max(lastSpan.dx, _minSpan);
      if (factor != 1.0 && rect.width > 0) {
        final focal = ((mid.dx - rect.left) / rect.width).clamp(0.0, 1.0);
        viewState.zoomXByFactor(factor, focal, maxTime: maxTime());
      }
    }
    if (axis == PinchAxis.vertical || axis == PinchAxis.both) {
      final factor = math.max(span.dy, _minSpan) / math.max(lastSpan.dy, _minSpan);
      if (factor != 1.0 && rect.height > 0) {
        final focal = ((mid.dy - rect.top) / rect.height).clamp(0.0, 1.0);
        viewState.zoomYAtFocal(factor, focal);
      }
    }

    _lastPinchSpan = span;
    _lastPinchMid = mid;
  }

  void _endGesture() {
    _lastPanPosition = null;
    _pinchStartSpan = null;
    _lastPinchSpan = null;
    _lastPinchMid = null;
    _resolver.reset();
    _dragging = false;
  }
}
