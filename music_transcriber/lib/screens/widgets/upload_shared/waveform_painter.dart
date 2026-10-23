import 'package:flutter/material.dart';

/// Draws a clip's loudness outline, dims what's outside the trim range and
/// marks the range edges and playhead. All positions are fractions 0..1.
class WaveformPainter extends CustomPainter {
  final List<double>? peaks;
  final double trimStart;
  final double trimEnd;
  final double playhead;
  final Color active;
  final Color dimmed;
  final Color handle;
  final Color playheadColor;

  const WaveformPainter({
    required this.peaks,
    required this.trimStart,
    required this.trimEnd,
    required this.playhead,
    required this.active,
    required this.dimmed,
    required this.handle,
    required this.playheadColor,
  });

  static const handleWidth = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBars(canvas, size);
    _paintHandle(canvas, size, trimStart);
    _paintHandle(canvas, size, trimEnd);
    final x = playhead * size.width;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height),
        Paint()..color = playheadColor..strokeWidth = 2);
  }

  void _paintBars(Canvas canvas, Size size) {
    final values = peaks;
    final mid = size.height / 2;
    if (values == null || values.isEmpty) {
      // No outline for compressed files: a plain bar keeps the layout steady.
      final bar = RRect.fromLTRBR(0, mid - 2, size.width, mid + 2, const Radius.circular(2));
      canvas.drawRRect(bar, Paint()..color = dimmed);
      canvas.drawRRect(
        RRect.fromLTRBR(trimStart * size.width, mid - 2, trimEnd * size.width, mid + 2,
            const Radius.circular(2)),
        Paint()..color = active,
      );
      return;
    }
    final step = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final center = (i + 0.5) / values.length;
      final half = (values[i] * (size.height / 2 - 6)).clamp(1.5, size.height / 2);
      final paint = Paint()
        ..color = center >= trimStart && center <= trimEnd ? active : dimmed
        ..strokeWidth = (step * 0.6).clamp(1.0, 4.0)
        ..strokeCap = StrokeCap.round;
      final x = center * size.width;
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  void _paintHandle(Canvas canvas, Size size, double fraction) {
    final x = fraction * size.width;
    canvas.drawRRect(
      RRect.fromLTRBR(x - handleWidth / 2, 0, x + handleWidth / 2, size.height,
          const Radius.circular(3)),
      Paint()..color = handle,
    );
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.peaks != peaks ||
      old.trimStart != trimStart ||
      old.trimEnd != trimEnd ||
      old.playhead != playhead ||
      old.active != active;
}
