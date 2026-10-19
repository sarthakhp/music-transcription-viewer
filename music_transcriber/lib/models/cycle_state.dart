import 'package:flutter/foundation.dart';

/// The cycle (loop) region, like GarageBand's cycle: a start and end time that
/// playback repeats while [enabled].
class CycleState extends ChangeNotifier {
  /// Shortest region that can be drawn or resized to, in seconds.
  static const double minLength = 0.5;

  bool _enabled = false;
  double _start = 0;
  double _end = 0;

  bool get enabled => _enabled;
  double get start => _start;
  double get end => _end;

  /// Whether a region exists (it can exist while switched off).
  bool get hasRegion => _end - _start >= minLength;

  /// Whether playback should currently loop.
  bool get active => _enabled && hasRegion;

  bool contains(double time) => time >= _start && time < _end;

  /// Replaces the region, clamped to [0, [maxTime]] and ordered.
  void setRegion(double a, double b, {required double maxTime, bool? enabled}) {
    var start = a < b ? a : b;
    var end = a < b ? b : a;
    start = start.clamp(0.0, maxTime).toDouble();
    end = end.clamp(0.0, maxTime).toDouble();
    if (end - start < minLength) end = (start + minLength).clamp(0.0, maxTime).toDouble();
    _apply(start, end, enabled ?? _enabled);
  }

  /// Moves the whole region so it starts at [start], keeping its length.
  void moveTo(double start, {required double maxTime}) {
    final length = _end - _start;
    final clamped = start.clamp(0.0, (maxTime - length).clamp(0.0, maxTime)).toDouble();
    _apply(clamped, clamped + length, _enabled);
  }

  void setStart(double time) {
    final start = time.clamp(0.0, _end - minLength).toDouble();
    _apply(start, _end, _enabled);
  }

  void setEnd(double time, {required double maxTime}) {
    final end = time.clamp(_start + minLength, maxTime).toDouble();
    _apply(_start, end, _enabled);
  }

  void setEnabled(bool value) => _apply(_start, _end, value);

  void restore({required bool enabled, required double start, required double end}) {
    final valid = end - start >= minLength;
    _apply(valid ? start : 0, valid ? end : 0, enabled && valid);
  }

  void clear() => _apply(0, 0, false);

  void _apply(double start, double end, bool enabled) {
    if (start == _start && end == _end && enabled == _enabled) return;
    _start = start;
    _end = end;
    _enabled = enabled;
    notifyListeners();
  }
}
