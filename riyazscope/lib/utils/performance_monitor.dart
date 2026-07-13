import 'dart:collection';
import 'package:flutter/scheduler.dart';

enum UserAction { idle, panX, panY, zoomX, zoomY, seek, playback }

class PerformanceMonitor {
  static final PerformanceMonitor instance = PerformanceMonitor._();
  PerformanceMonitor._();

  bool _running = false;
  UserAction _currentAction = UserAction.idle;
  DateTime? _actionStart;
  final _frameTimes = Queue<_FrameRecord>();

  static const _windowDuration = Duration(seconds: 2);
  static const _logInterval = Duration(seconds: 2);

  DateTime _lastLogTime = DateTime.now();

  // Counters reset each log interval
  int _totalFrames = 0;
  double _worstFrameMs = 0;
  final _actionCounts = <UserAction, int>{};

  void start() {
    if (_running) return;
    _running = true;
    _lastLogTime = DateTime.now();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // debugPrint('[Perf] Monitor started');
  }

  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    // debugPrint('[Perf] Monitor stopped');
  }

  void reportAction(UserAction action) {
    if (_currentAction == UserAction.idle && action != UserAction.idle) {
      _actionStart = DateTime.now();
    }
    _currentAction = action;
  }

  void reportIdle() {
    if (_currentAction != UserAction.idle && _actionStart != null) {
      final duration = DateTime.now().difference(_actionStart!);
      if (duration.inMilliseconds > 100) {
        // debugPrint('[Perf] Action ${_currentAction.name} lasted ${duration.inMilliseconds}ms');
      }
    }
    _currentAction = UserAction.idle;
    _actionStart = null;
  }

  void _onTimings(List<FrameTiming> timings) {
    final now = DateTime.now();

    for (final t in timings) {
      final buildMs = (t.buildDuration.inMicroseconds / 1000.0);
      final rasterMs = (t.rasterDuration.inMicroseconds / 1000.0);
      final totalMs = buildMs + rasterMs;

      _frameTimes.addLast(_FrameRecord(
        timestamp: now,
        buildMs: buildMs,
        rasterMs: rasterMs,
        action: _currentAction,
      ));

      _totalFrames++;
      if (totalMs > _worstFrameMs) _worstFrameMs = totalMs;
      _actionCounts[_currentAction] = (_actionCounts[_currentAction] ?? 0) + 1;
    }

    // Evict old records
    final cutoff = now.subtract(_windowDuration);
    while (_frameTimes.isNotEmpty && _frameTimes.first.timestamp.isBefore(cutoff)) {
      _frameTimes.removeFirst();
    }

    // Periodic log
    if (now.difference(_lastLogTime) >= _logInterval) {
      _printSummary();
      _lastLogTime = now;
    }
  }

  void _printSummary() {
    if (_totalFrames == 0) return;

    // Reset interval counters
    _totalFrames = 0;
    _worstFrameMs = 0;
    _actionCounts.clear();
  }
}

class _FrameRecord {
  final DateTime timestamp;
  final double buildMs;
  final double rasterMs;
  final UserAction action;

  _FrameRecord({
    required this.timestamp,
    required this.buildMs,
    required this.rasterMs,
    required this.action,
  });
}
