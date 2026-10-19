import 'package:flutter/material.dart';
import '../../models/cycle_state.dart';
import '../../models/view_state.dart';
import '../graph_constants.dart';

/// Which part of the cycle bar a point is over.
enum CycleHit { none, startEdge, endEdge, body }

/// Geometry and drawing of the GarageBand-style cycle bar.
///
/// The bar lives in the strip above the plot (the top inset). Its region is
/// also tinted down through the plot so you can see what will loop.
class CycleBar {
  CycleBar({required this.cycle, required this.viewState, required this.insets, required this.size});

  final CycleState cycle;
  final ViewState viewState;
  final GraphInsets insets;
  final Size size;

  static const Color color = Color(0xFFF5C518);

  /// Pixels either side of an edge that still grab it.
  static const double edgeGrab = 9;
  static const double _edgeWidth = 4;

  Rect get _plot => insets.rectFor(size);
  double get _span => viewState.viewEndTime - viewState.viewStartTime;

  /// The strip that holds the bar and accepts cycle gestures.
  Rect get strip => Rect.fromLTRB(_plot.left, 0, _plot.right, insets.top);

  double xOf(double time) =>
      _plot.left + (time - viewState.viewStartTime) / (_span <= 0 ? 1 : _span) * _plot.width;

  double timeOf(double x) =>
      viewState.viewStartTime + (x - _plot.left) / (_plot.width <= 0 ? 1 : _plot.width) * _span;

  bool inStrip(Offset p) => strip.contains(p);

  CycleHit hit(Offset p) {
    if (!cycle.hasRegion || !inStrip(p)) return CycleHit.none;
    final a = xOf(cycle.start);
    final b = xOf(cycle.end);
    if ((p.dx - a).abs() <= edgeGrab) return CycleHit.startEdge;
    if ((p.dx - b).abs() <= edgeGrab) return CycleHit.endEdge;
    if (p.dx > a && p.dx < b) return CycleHit.body;
    return CycleHit.none;
  }

  void paint(Canvas canvas) {
    final bar = strip.deflate(0).intersect(Rect.fromLTRB(strip.left, 2, strip.right, strip.bottom - 2));
    if (!cycle.hasRegion) {
      _paintHint(canvas, bar);
      return;
    }
    final on = cycle.enabled;
    final fill = on ? color : Colors.grey;
    final a = xOf(cycle.start).clamp(_plot.left, _plot.right).toDouble();
    final b = xOf(cycle.end).clamp(_plot.left, _plot.right).toDouble();
    if (b <= a) return;

    // Tint over the plot so the looping part reads at a glance.
    canvas.drawRect(
      Rect.fromLTRB(a, _plot.top, b, _plot.bottom),
      Paint()..color = fill.withValues(alpha: on ? 0.10 : 0.05),
    );

    final region = RRect.fromRectAndRadius(
      Rect.fromLTRB(a, bar.top, b, bar.bottom),
      const Radius.circular(4),
    );
    canvas.drawRRect(region, Paint()..color = fill.withValues(alpha: on ? 0.92 : 0.45));

    final edge = Paint()..color = Colors.black.withValues(alpha: on ? 0.35 : 0.25);
    if (xOf(cycle.start) >= _plot.left) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(a, bar.top, _edgeWidth, bar.height),
          const Radius.circular(2),
        ),
        edge,
      );
    }
    if (xOf(cycle.end) <= _plot.right) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(b - _edgeWidth, bar.top, _edgeWidth, bar.height),
          const Radius.circular(2),
        ),
        edge,
      );
    }

    // A loop glyph in the bar when there is room for it.
    if (b - a > 40) {
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.loop_rounded.codePoint),
          style: TextStyle(
            fontFamily: Icons.loop_rounded.fontFamily,
            package: Icons.loop_rounded.fontPackage,
            fontSize: bar.height - 4,
            color: Colors.black.withValues(alpha: on ? 0.6 : 0.4),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(a + _edgeWidth + 4, bar.center.dy - tp.height / 2));
    }
  }

  /// Faint prompt shown until a region exists.
  void _paintHint(Canvas canvas, Rect bar) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(4)),
      Paint()..color = Colors.grey.withValues(alpha: 0.10),
    );
  }
}
