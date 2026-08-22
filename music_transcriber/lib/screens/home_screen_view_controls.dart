part of 'home_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

final _digitKeyMap = {
  LogicalKeyboardKey.digit1: 1, LogicalKeyboardKey.numpad1: 1,
  LogicalKeyboardKey.digit2: 2, LogicalKeyboardKey.numpad2: 2,
  LogicalKeyboardKey.digit3: 3, LogicalKeyboardKey.numpad3: 3,
  LogicalKeyboardKey.digit4: 4, LogicalKeyboardKey.numpad4: 4,
  LogicalKeyboardKey.digit5: 5, LogicalKeyboardKey.numpad5: 5,
  LogicalKeyboardKey.digit6: 6, LogicalKeyboardKey.numpad6: 6,
  LogicalKeyboardKey.digit7: 7, LogicalKeyboardKey.numpad7: 7,
  LogicalKeyboardKey.digit8: 8, LogicalKeyboardKey.numpad8: 8,
  LogicalKeyboardKey.digit9: 9, LogicalKeyboardKey.numpad9: 9,
};

extension _HomeScreenViewControls on _HomeScreenState {

  // --- Scroll animation (needs AnimationController from State) --------------

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

  // --- Gesture callbacks (passed to PitchGraph) -----------------------------

  void _handleZoom(double zoomDelta, double focalPointRatio) {
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120.0;
    _viewState.zoomXAtFocal(zoomDelta, focalPointRatio, maxTime: maxTime);
  }

  void _handleYZoom(double scaleFactor) {
    _viewState.zoomY(scaleFactor);
  }

  void _handleYPan(double scrollDeltaY) {
    _viewState.panY(scrollDeltaY);
  }

  void _handlePan(double panDelta) {
    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    _viewState.panX(panDelta, maxTime: maxTime);
  }

  // --- Seek -----------------------------------------------------------------

  void _seekTo(double time) {
    PerformanceMonitor.instance.reportAction(UserAction.seek);
    _audioService.seekToSeconds(time);

    final maxTime = context.read<AppState>().pitchData?.maxTime ?? 120;
    final maxStart = max(0.0, maxTime - _viewState.viewWindowSize).toDouble();
    final centeredStart =
        (time - _viewState.viewWindowSize / 2).clamp(0.0, maxStart).toDouble();

    if (_viewState.autoScroll) {
      // Keep playhead centered with auto-scroll. Set immediately (no scroll
      // animation) so continuous follow during playback doesn't fight the tween.
      _scrollAnimationController.stop();
      _viewState.setViewStartTime(centeredStart);
      return;
    }

    // Auto-scroll off: only move the window if the target is off-screen.
    final isOutsideView =
        time < _viewState.viewStartTime || time > _viewState.viewEndTime;
    if (isOutsideView) {
      _animateScrollTo(centeredStart);
    }
  }

  // --- Speed ----------------------------------------------------------------

  static const _speedPresets = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

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

  // --- Keyboard shortcuts ---------------------------------------------------

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

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

    final isPlus = event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add;
    final isMinus = event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.underscore;
    if (isPlus || isMinus) {
      // Cmd held: let the browser handle page zoom (Cmd+Shift+= / Cmd+-)
      if (HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed) {
        return KeyEventResult.ignored;
      }
      if (HardwareKeyboard.instance.isShiftPressed) {
        // Shift+/- : horizontal zoom (zoomXAtFocal uses +delta=in, -delta=out)
        _viewState.zoomXAtFocal(isPlus ? 1.0 : -1.0, 0.5, maxTime: maxTime);
      } else {
        // +/- : vertical zoom
        _viewState.zoomY(isPlus ? ViewState.zoomFactor : 1.0 / ViewState.zoomFactor);
      }
      return KeyEventResult.handled;
    }

    // Top-row and numpad 0–9: seek to 0%, 10%, 20%, … 90% of duration (YouTube-style)
    if (event.logicalKey == LogicalKeyboardKey.digit0 ||
        event.logicalKey == LogicalKeyboardKey.numpad0) {
      _seekTo(0);
      return KeyEventResult.handled;
    }
    final digitN = _digitKeyMap[event.logicalKey];
    if (digitN != null) {
      _seekTo(maxTime * digitN / 10);
      return KeyEventResult.handled;
    }

    // A: toggle auto-scroll during playback
    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      _viewState.setAutoScroll(!_viewState.autoScroll);
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
