part of 'home_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _HomeScreenViewControls on _HomeScreenState {
  void _onScrollAnimationUpdate() {
    if (_scrollAnimation != null) {
      setState(() => _viewStartTime = _scrollAnimation!.value);
    }
  }

  void _updateViewWindow(double currentTime, double maxTime) {
    if (!_autoScroll) return;

    final viewEndTime = _viewStartTime + _viewWindowSize;

    if (currentTime > viewEndTime - _viewWindowSize * 0.1) {
      final newStartTime = (currentTime - _viewWindowSize * 0.1)
          .clamp(0.0, max(0.0, maxTime - _viewWindowSize).toDouble());
      _animateScrollTo(newStartTime);
    } else if (currentTime < _viewStartTime) {
      final newStartTime =
          currentTime.clamp(0.0, max(0.0, maxTime - _viewWindowSize).toDouble());
      _animateScrollTo(newStartTime);
    }
  }

  void _zoomIn() {
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    final centerTime = _viewStartTime + _viewWindowSize / 2;
    setState(() {
      _viewWindowSize = (_viewWindowSize / _HomeScreenState._zoomFactor)
          .clamp(_HomeScreenState._minWindowSize, _HomeScreenState._maxWindowSize);
      _viewStartTime =
          (centerTime - _viewWindowSize / 2).clamp(0, max(0, maxTime - _viewWindowSize));
      _autoScroll = false;
    });
    _reEnableAutoScrollAfterDelay();
  }

  void _zoomOut() {
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    final centerTime = _viewStartTime + _viewWindowSize / 2;
    setState(() {
      _viewWindowSize = (_viewWindowSize * _HomeScreenState._zoomFactor)
          .clamp(_HomeScreenState._minWindowSize, _HomeScreenState._maxWindowSize);
      _viewStartTime =
          (centerTime - _viewWindowSize / 2).clamp(0, max(0, maxTime - _viewWindowSize));
      _autoScroll = false;
    });
    _reEnableAutoScrollAfterDelay();
  }

  void _resetZoom() {
    setState(() {
      _viewWindowSize = 30;
      _viewStartTime = 0;
      _yZoomScale = 1.0;
      _yPanOffset = 0.0;
      _autoScroll = true;
    });
  }

  void _handleZoom(double zoomDelta, double focalPointRatio) {
    PerformanceMonitor.instance.reportAction(UserAction.zoomX);
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120.0;
    final focalTime = _viewStartTime + _viewWindowSize * focalPointRatio;

    final newWindowSize = (zoomDelta > 0
            ? _viewWindowSize / (1 + zoomDelta.abs() * 0.1)
            : _viewWindowSize * (1 + zoomDelta.abs() * 0.1))
        .clamp(_HomeScreenState._minWindowSize, _HomeScreenState._maxWindowSize);

    final newStartTime = (focalTime - newWindowSize * focalPointRatio)
        .clamp(0.0, max(0.0, maxTime - newWindowSize).toDouble());

    setState(() {
      _viewWindowSize = newWindowSize;
      _viewStartTime = newStartTime;
      _autoScroll = false;
    });
    _reEnableAutoScrollAfterDelay();
  }

  void _handleYZoom(double scaleFactor) {
    PerformanceMonitor.instance.reportAction(UserAction.zoomY);
    setState(() {
      _yZoomScale = (_yZoomScale * scaleFactor)
          .clamp(_HomeScreenState._minYZoomScale, _HomeScreenState._maxYZoomScale);
    });
  }

  void _handleYPan(double scrollDeltaY) {
    PerformanceMonitor.instance.reportAction(UserAction.panY);
    final pitchData = context.read<AppState>().pitchData;
    if (pitchData == null) return;
    final appState = context.read<AppState>();
    final range = pitchData.frequencyRange;
    final baseSpan = (frequencyToMidi(range.$2, referenceFrequency: appState.referenceFrequency).ceil() + 2) -
        (frequencyToMidi(range.$1, referenceFrequency: appState.referenceFrequency).floor() - 2);
    final currentSpan = baseSpan / _yZoomScale;
    final midiDelta = -scrollDeltaY * currentSpan / 400.0;
    setState(() {
      _yPanOffset =
          (_yPanOffset + midiDelta).clamp(-baseSpan.toDouble(), baseSpan.toDouble());
    });
  }

  void _handlePan(double panDelta) {
    PerformanceMonitor.instance.reportAction(UserAction.panX);
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    setState(() {
      _viewStartTime =
          (_viewStartTime + panDelta).clamp(0.0, max(0.0, maxTime - _viewWindowSize));
      _autoScroll = false;
    });
    _reEnableAutoScrollAfterDelay();
  }

  void _animateScrollTo(double targetTime) {
    _scrollAnimation = Tween<double>(
      begin: _viewStartTime,
      end: targetTime,
    ).animate(CurvedAnimation(
      parent: _scrollAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _scrollAnimationController.forward(from: 0);
  }

  void _reEnableAutoScrollAfterDelay() {
    // Auto-scroll is now only re-enabled via the Auto-scroll button.
  }

  void _seekTo(double time) {
    PerformanceMonitor.instance.reportAction(UserAction.seek);
    final playerPosBefore = _audioService.position.inMilliseconds / 1000.0;
    debugPrint('[Seek] target=$time  playerPosBefore=$playerPosBefore  _lastKnownPosition=$_lastKnownPosition  display=${context.read<AppState>().currentTime}');
    _audioService.seekToSeconds(time);

    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    final viewEndTime = _viewStartTime + _viewWindowSize;
    final isOutsideView = time < _viewStartTime || time > viewEndTime;

    setState(() => _autoScroll = false);

    if (isOutsideView) {
      final newStartTime = (time - _viewWindowSize / 2)
          .clamp(0.0, max(0.0, maxTime - _viewWindowSize).toDouble());
      _animateScrollTo(newStartTime);
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _autoScroll = true);
    });
  }

  static const _speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  void _stepSpeed(int direction) {
    final currentIndex = _speedPresets.indexOf(_playbackSpeed);
    if (currentIndex < 0) return;
    final newIndex = (currentIndex + direction).clamp(0, _speedPresets.length - 1);
    _setSpeed(_speedPresets[newIndex]);
  }

  void _setSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _audioService.setSpeed(speed);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final appState = context.read<AppState>();
    if (!appState.isReady) return KeyEventResult.ignored;

    final currentTime = appState.currentTime;
    final maxTime = appState.pitchData?.maxTime ?? 120;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _audioService.togglePlayPause();
      return KeyEventResult.handled;
    }

    // Cmd+Shift+Up/Down: transpose pitch (check before plain arrow keys)
    if (HardwareKeyboard.instance.isMetaPressed &&
        HardwareKeyboard.instance.isShiftPressed) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_transposeAmount < 12) {
          setState(() => _transposeAmount = _transposeAmount + 1);
          _audioService.setPitchSemitones(_transposeAmount);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_transposeAmount > -12) {
          setState(() => _transposeAmount = _transposeAmount - 1);
          _audioService.setPitchSemitones(_transposeAmount);
        }
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekTo((currentTime - AudioControls.seekStepSeconds).clamp(0, maxTime));
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekTo((currentTime + AudioControls.seekStepSeconds).clamp(0, maxTime));
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add) {
      _zoomIn();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.minus) {
      _zoomOut();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.digit0) {
      _resetZoom();
      return KeyEventResult.handled;
    }

    // Speed controls: [ slower, ] faster, \ reset
    if (event.logicalKey == LogicalKeyboardKey.bracketLeft) {
      _stepSpeed(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.bracketRight) {
      _stepSpeed(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backslash) {
      _setSpeed(1.0);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
