import 'package:flutter/material.dart';
import '../models/view_state.dart';
import '../utils/responsive.dart';
import 'mobile_player/mobile_player_panel.dart';
import 'audio_controls/control_group.dart';
import 'audio_controls/playback_controls.dart';
import 'audio_controls/zoom_control.dart';
import 'audio_controls/speed_control.dart';
import 'audio_controls/transpose_control.dart';
import 'audio_controls/sargam_control.dart';
import 'audio_controls/reference_frequency_control.dart';

/// Audio playback controls widget.
///
/// Composes [SeekSlider] + transport/secondary controls, switching between
/// a single-row "wide" layout and a stacked "narrow" layout at <960px width.
/// Sub-controls live in `audio_controls/` for maintainability.
class AudioControls extends StatelessWidget {
  static const double seekStepSeconds = TransportButtons.seekStepSeconds;
  final bool isPlaying;
  final double currentTime;
  final double duration;
  final double referenceFrequency;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onReferenceFrequencyChange;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final double viewWindowSize;
  final int transposeAmount;
  final ValueChanged<int> onTransposeChanged;
  final double playbackSpeed;
  final ValueChanged<double> onSpeedChanged;
  final bool sargamEnabled;
  final ValueChanged<bool> onSargamToggled;
  final int scaleRoot;
  final ValueChanged<int> onScaleRootChanged;

  /// Needed by the phone layout's zoom sheet.
  final ViewState? viewState;

  const AudioControls({
    super.key,
    required this.isPlaying,
    required this.currentTime,
    required this.duration,
    required this.referenceFrequency,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
    required this.onReferenceFrequencyChange,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.viewWindowSize,
    required this.transposeAmount,
    required this.onTransposeChanged,
    required this.playbackSpeed,
    required this.onSpeedChanged,
    required this.sargamEnabled,
    required this.onSargamToggled,
    required this.scaleRoot,
    required this.onScaleRootChanged,
    this.viewState,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.sizeOf(context).width < 960;

    final layout = ViewerLayout.of(context);
    final vs = viewState;
    if (layout.isPhone && vs != null) {
      return MobilePlayerPanel(
        layout: layout,
        isPlaying: isPlaying,
        currentTime: currentTime,
        duration: duration,
        onPlayPause: onPlayPause,
        onStop: onStop,
        onSeek: onSeek,
        playbackSpeed: playbackSpeed,
        onSpeedChanged: onSpeedChanged,
        transposeAmount: transposeAmount,
        onTransposeChanged: onTransposeChanged,
        sargamEnabled: sargamEnabled,
        onSargamToggled: onSargamToggled,
        scaleRoot: scaleRoot,
        onScaleRootChanged: onScaleRootChanged,
        referenceFrequency: referenceFrequency,
        onReferenceFrequencyChange: onReferenceFrequencyChange,
        viewState: vs,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SeekSlider(
            currentTime: currentTime,
            duration: duration,
            onSeek: onSeek,
            touchFriendly: true,
          ),
          const SizedBox(height: 8),
          if (isNarrow) _buildNarrowControls() else _buildWideControls(),
        ],
      ),
    );
  }

  /// The labelled setting groups, shared by the wide and mid-width layouts.
  /// A group lights up (teal caption + outline) when its value is not the default.
  List<Widget> _buildGroups() {
    return [
      ControlGroup(
        label: 'Zoom',
        child: ZoomControl(
          onZoomIn: onZoomIn,
          onZoomOut: onZoomOut,
          viewWindowSize: viewWindowSize,
        ),
      ),
      ControlGroup(
        label: 'Speed',
        modified: playbackSpeed != 1.0,
        onReset: () => onSpeedChanged(1.0),
        child: SpeedControl(speed: playbackSpeed, onChanged: onSpeedChanged),
      ),
      ControlGroup(
        label: 'Key',
        modified: transposeAmount != 0,
        onReset: () => onTransposeChanged(0),
        child: TransposeControl(amount: transposeAmount, onChanged: onTransposeChanged),
      ),
      ControlGroup(
        label: 'Root / notation',
        modified: sargamEnabled,
        onReset: () => onSargamToggled(false),
        child: SargamControl(
          enabled: sargamEnabled,
          onToggled: onSargamToggled,
          scaleRoot: scaleRoot,
          onScaleRootChanged: onScaleRootChanged,
        ),
      ),
      ControlGroup(
        label: 'Tuning (A4)',
        modified: referenceFrequency != 440.0,
        onReset: () => onReferenceFrequencyChange(440.0),
        child: ReferenceFrequencyControl(
          frequency: referenceFrequency,
          onChanged: onReferenceFrequencyChange,
        ),
      ),
    ];
  }

  Widget _withGaps(List<Widget> items, double gap) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            items[i],
          ],
        ],
      );

  /// Wide layout: transport on the left as the primary action, setting
  /// groups right-aligned. FittedBox shrinks them slightly on mid-width
  /// windows instead of overflowing.
  Widget _buildWideControls() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildWideTransport(),
        const SizedBox(width: 24),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: _withGaps(_buildGroups(), 12),
          ),
        ),
      ],
    );
  }

  Widget _buildWideTransport() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: () => onSeek(0),
          tooltip: 'Back to start',
        ),
        const SizedBox(width: 4),
        // Soft teal glow while playing, so state is visible at a glance.
        Builder(builder: (context) {
          final primary = Theme.of(context).colorScheme.primary;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: isPlaying
                  ? [BoxShadow(color: primary.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 1)]
                  : const [],
            ),
            child: IconButton.filled(
              iconSize: 32,
              constraints: const BoxConstraints.tightFor(width: 56, height: 56),
              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              onPressed: onPlayPause,
              tooltip: isPlaying ? 'Pause (Space)' : 'Play (Space)',
            ),
          );
        }),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.replay_rounded),
          onPressed: () => onSeek((currentTime - seekStepSeconds).clamp(0, duration)),
          tooltip: 'Back ${seekStepSeconds.toInt()}s',
        ),
        IconButton(
          icon: Transform.flip(flipX: true, child: const Icon(Icons.replay_rounded)),
          onPressed: () => onSeek((currentTime + seekStepSeconds).clamp(0, duration)),
          tooltip: 'Forward ${seekStepSeconds.toInt()}s',
        ),
      ],
    );
  }

  /// Mid-width layout (tablets, narrow windows): transport centred, the
  /// labelled groups wrapping underneath.
  Widget _buildNarrowControls() {
    return Column(
      children: [
        _buildWideTransport(),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: _buildGroups(),
        ),
      ],
    );
  }
}
