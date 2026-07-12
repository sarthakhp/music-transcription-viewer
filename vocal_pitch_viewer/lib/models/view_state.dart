import 'dart:math' show max;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../utils/performance_monitor.dart';
import 'job_settings.dart';

class ViewState extends ChangeNotifier {
  // --- X-axis (time) --------------------------------------------------------
  double _viewStartTime = 0;
  double _viewWindowSize = 30;

  static const double minWindowSize = 5;
  static const double maxWindowSize = 120;
  static const double zoomFactor = 1.2;

  double get viewStartTime => _viewStartTime;
  double get viewEndTime => _viewStartTime + _viewWindowSize;
  double get viewWindowSize => _viewWindowSize;

  // --- Y-axis (MIDI range) --------------------------------------------------
  double _yZoomScale = 1.0;
  double _yPanOffset = 0.0;

  static const double minYZoomScale = 0.5;
  static const double maxYZoomScale = 6.0;

  double get yZoomScale => _yZoomScale;
  double get yPanOffset => _yPanOffset;

  // --- Auto-scroll ----------------------------------------------------------
  bool _autoScroll = true;
  bool get autoScroll => _autoScroll;

  void setAutoScroll(bool value) {
    if (_autoScroll == value) return;
    _autoScroll = value;
    notifyListeners();
  }

  // --- Frame-rate throttle --------------------------------------------------
  //
  // Trackpads fire scroll events at 120Hz+. We accumulate state changes
  // silently and flush one notifyListeners() per animation frame so the
  // widget tree rebuilds at most once per vsync (~60fps).
  bool _dirty = false;

  void _markDirty() {
    if (_dirty) return;
    _dirty = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (_dirty) {
        _dirty = false;
        notifyListeners();
      }
    });
  }

  // --- Pan ------------------------------------------------------------------

  void panX(double delta, {required double maxTime}) {
    PerformanceMonitor.instance.reportAction(UserAction.panX);
    _viewStartTime = (_viewStartTime + delta)
        .clamp(0.0, max(0.0, maxTime - _viewWindowSize));
    _autoScroll = false;
    _markDirty();
  }

  void panY(double scrollDeltaY) {
    PerformanceMonitor.instance.reportAction(UserAction.panY);
    // Use the stored base range (which includes instrument data and transpose)
    // so panning can reach all visible content after zooming in.
    final baseSpan = _baseMaxMidi - _baseMinMidi;
    final currentSpan = baseSpan / _yZoomScale;
    final midiDelta = -scrollDeltaY * currentSpan / 150.0;
    _yPanOffset = (_yPanOffset + midiDelta).clamp(-baseSpan, baseSpan);
    _markDirty();
  }

  // --- Zoom -----------------------------------------------------------------

  void zoomIn({required double maxTime}) {
    final centerTime = _viewStartTime + _viewWindowSize / 2;
    _viewWindowSize = (_viewWindowSize / zoomFactor)
        .clamp(minWindowSize, maxWindowSize);
    _viewStartTime = (centerTime - _viewWindowSize / 2)
        .clamp(0, max(0, maxTime - _viewWindowSize));
    _autoScroll = false;
    _markDirty();
  }

  void zoomOut({required double maxTime}) {
    final centerTime = _viewStartTime + _viewWindowSize / 2;
    _viewWindowSize = (_viewWindowSize * zoomFactor)
        .clamp(minWindowSize, maxWindowSize);
    _viewStartTime = (centerTime - _viewWindowSize / 2)
        .clamp(0, max(0, maxTime - _viewWindowSize));
    _autoScroll = false;
    _markDirty();
  }

  void zoomXAtFocal(double zoomDelta, double focalPointRatio,
      {required double maxTime}) {
    PerformanceMonitor.instance.reportAction(UserAction.zoomX);
    final focalTime = _viewStartTime + _viewWindowSize * focalPointRatio;
    final newWindowSize = (zoomDelta > 0
            ? _viewWindowSize / (1 + zoomDelta.abs() * 0.1)
            : _viewWindowSize * (1 + zoomDelta.abs() * 0.1))
        .clamp(minWindowSize, maxWindowSize);
    _viewStartTime = (focalTime - newWindowSize * focalPointRatio)
        .clamp(0.0, max(0.0, maxTime - newWindowSize).toDouble());
    _viewWindowSize = newWindowSize;
    _autoScroll = false;
    _markDirty();
  }

  void zoomY(double scaleFactor) {
    PerformanceMonitor.instance.reportAction(UserAction.zoomY);
    _yZoomScale = (_yZoomScale * scaleFactor)
        .clamp(minYZoomScale, maxYZoomScale);
    _markDirty();
  }

  void resetZoom() {
    _viewWindowSize = 30;
    _viewStartTime = 0;
    _yZoomScale = 1.0;
    _yPanOffset = 0.0;
    _autoScroll = true;
    notifyListeners();
  }

  // --- Auto-scroll during playback -----------------------------------------

  void updateViewWindowForPlayback(double currentTime, double maxTime) {
    if (!_autoScroll) return;

    final viewEnd = _viewStartTime + _viewWindowSize;
    double? newStartTime;

    if (currentTime > viewEnd - _viewWindowSize * 0.1) {
      newStartTime = (currentTime - _viewWindowSize * 0.1)
          .clamp(0.0, max(0.0, maxTime - _viewWindowSize).toDouble());
    } else if (currentTime < _viewStartTime) {
      newStartTime = currentTime
          .clamp(0.0, max(0.0, maxTime - _viewWindowSize).toDouble());
    }

    if (newStartTime != null) {
      _viewStartTime = newStartTime;
      notifyListeners();
    }
  }

  void setViewStartTime(double time) {
    _viewStartTime = time;
    notifyListeners();
  }

  // --- MIDI range (computed from zoom/pan + base range) ---------------------

  double _baseMinMidi = 40;
  double _baseMaxMidi = 84;

  void setBaseMidiRange(double baseMin, double baseMax) {
    _baseMinMidi = baseMin;
    _baseMaxMidi = baseMax;
  }

  double get effectiveMinMidi {
    final center = (_baseMinMidi + _baseMaxMidi) / 2.0 + _yPanOffset;
    final halfSpan = (_baseMaxMidi - _baseMinMidi) / 2.0 / _yZoomScale;
    return center - halfSpan;
  }

  double get effectiveMaxMidi {
    final center = (_baseMinMidi + _baseMaxMidi) / 2.0 + _yPanOffset;
    final halfSpan = (_baseMaxMidi - _baseMinMidi) / 2.0 / _yZoomScale;
    return center + halfSpan;
  }

  // --- Save/Restore view state ----------------------------------------------

  /// Extract view state to save to per-job settings
  JobSettings extractViewSettings({
    required double playbackSpeed,
    required int transposeAmount,
    required bool sargamEnabled,
    required int scaleRoot,
  }) {
    return JobSettings(
      viewStartTime: _viewStartTime,
      viewWindowSize: _viewWindowSize,
      yZoomScale: _yZoomScale,
      yPanOffset: _yPanOffset,
      autoScroll: _autoScroll,
      playbackSpeed: playbackSpeed,
      transposeAmount: transposeAmount,
      sargamEnabled: sargamEnabled,
      scaleRoot: scaleRoot,
    );
  }

  /// Restore view state from saved settings
  void applyViewSettings(JobSettings settings) {
    _viewStartTime = settings.viewStartTime;
    _viewWindowSize = settings.viewWindowSize;
    _yZoomScale = settings.yZoomScale;
    _yPanOffset = settings.yPanOffset;
    _autoScroll = settings.autoScroll;
    notifyListeners();
  }
}
