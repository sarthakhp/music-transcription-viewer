part of 'home_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _HomeScreenViewControls on _HomeScreenState {

  // ─── Scroll animation (needs AnimationController from State) ──────────────

  void _onScrollAnimationUpdate() {
    if (_scrollAnimation != null) {
      _viewState.setViewStartTime(_scrollAnimation!.value);
    }
  }

  void _animateScrollTo(double targetTime) {
    _scrollAnimation = Tween<double>(
      begin: _viewState.viewStartTime,
      end: targetTime,
    ).animate(CurvedAnimation(
      parent: _scrollAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _scrollAnimationController.forward(from: 0);
  }

  // ─── Gesture callbacks (passed to PitchGraph) ─────────────────────────────

  void _handleZoom(double zoomDelta, double focalPointRatio) {
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120.0;
    _viewState.zoomXAtFocal(zoomDelta, focalPointRatio, maxTime: maxTime);
  }

  void _handleYZoom(double scaleFactor) {
    _viewState.zoomY(scaleFactor);
  }

  void _handleYPan(double scrollDeltaY) {
    final pitchData = context.read<AppState>().pitchData;
    if (pitchData == null) return;
    final appState = context.read<AppState>();
    final range = pitchData.frequencyRange;
    final baseSpan = (frequencyToMidi(range.$2, referenceFrequency: appState.referenceFrequency).ceil() + 2) -
        (frequencyToMidi(range.$1, referenceFrequency: appState.referenceFrequency).floor() - 2);
    _viewState.panY(scrollDeltaY, baseSpan: baseSpan);
  }

  void _handlePan(double panDelta) {
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    _viewState.panX(panDelta, maxTime: maxTime);
  }

  // ─── Seek ─────────────────────────────────────────────────────────────────

  void _seekTo(double time) {
    PerformanceMonitor.instance.reportAction(UserAction.seek);
    _audioService.seekToSeconds(time);

    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    final isOutsideView = time < _viewState.viewStartTime || time > _viewState.viewEndTime;

    _viewState.setAutoScroll(false);

    if (isOutsideView) {
      final newStartTime = (time - _viewState.viewWindowSize / 2)
          .clamp(0.0, max(0.0, maxTime - _viewState.viewWindowSize).toDouble());
      _animateScrollTo(newStartTime);
    }
  }

  // ─── Speed ────────────────────────────────────────────────────────────────

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

  // ─── Keyboard shortcuts ───────────────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Don't intercept keys when a text field has focus
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null &&
        primaryFocus.context != null &&
        primaryFocus.context!.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }

    final appState = context.read<AppState>();
    if (!appState.isReady) return KeyEventResult.ignored;

    final currentTime = appState.currentTime;
    final maxTime = appState.pitchData?.maxTime ?? 120;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _audioService.togglePlayPause();
      return KeyEventResult.handled;
    }

    // Cmd+Shift+Up/Down: transpose pitch
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
      _viewState.zoomY(ViewState.zoomFactor);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.minus) {
      _viewState.zoomY(1.0 / ViewState.zoomFactor);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.digit0) {
      _viewState.resetZoom();
      return KeyEventResult.handled;
    }

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
