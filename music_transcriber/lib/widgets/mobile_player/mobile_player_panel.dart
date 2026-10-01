import 'package:flutter/material.dart';
import '../../models/view_state.dart';
import '../../utils/music_utils.dart';
import '../../utils/responsive.dart';
import '../audio_controls/playback_controls.dart';
import '../audio_controls/speed_control.dart';
import 'control_pill.dart';
import 'key_sheet.dart';
import 'notation_sheet.dart';
import 'speed_sheet.dart';
import 'view_sheet.dart';

/// Touch-first player panel for phones.
///
/// Portrait: seek bar, one large transport row, then four thumb-sized pills
/// (Speed / Key / Notes / Zoom). Each pill opens a bottom sheet with big
/// controls instead of cramming tiny steppers into the panel, which leaves
/// the pitch graph as much height as possible.
/// Landscape: everything shares a single short row.
class MobilePlayerPanel extends StatelessWidget {
  static const double skipSeconds = 5;

  final ViewerLayout layout;
  final bool isPlaying;
  final double currentTime;
  final double duration;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<double> onSeek;

  final double playbackSpeed;
  final ValueChanged<double> onSpeedChanged;
  final int transposeAmount;
  final ValueChanged<int> onTransposeChanged;
  final bool sargamEnabled;
  final ValueChanged<bool> onSargamToggled;
  final int scaleRoot;
  final ValueChanged<int> onScaleRootChanged;
  final double referenceFrequency;
  final ValueChanged<double> onReferenceFrequencyChange;
  final ViewState viewState;

  const MobilePlayerPanel({
    super.key,
    required this.layout,
    required this.isPlaying,
    required this.currentTime,
    required this.duration,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
    required this.playbackSpeed,
    required this.onSpeedChanged,
    required this.transposeAmount,
    required this.onTransposeChanged,
    required this.sargamEnabled,
    required this.onSargamToggled,
    required this.scaleRoot,
    required this.onScaleRootChanged,
    required this.referenceFrequency,
    required this.onReferenceFrequencyChange,
    required this.viewState,
  });

  bool get _isLandscape => layout == ViewerLayout.phoneLandscape;

  void _skip(double delta) => onSeek((currentTime + delta).clamp(0, duration).toDouble());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pills = _buildPills(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, _isLandscape ? 4 : 2, 16, _isLandscape ? 4 : 10),
      child: _isLandscape ? _buildLandscape(pills) : _buildPortrait(pills),
    );
  }

  Widget _buildPortrait(List<Widget> pills) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeekSlider(
          currentTime: currentTime,
          duration: duration,
          onSeek: onSeek,
          touchFriendly: true,
        ),
        _buildTransport(playSize: 64),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < pills.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: pills[i]),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLandscape(List<Widget> pills) {
    return Row(
      children: [
        _buildTransport(playSize: 48, includeStop: false),
        const SizedBox(width: 8),
        Expanded(
          child: SeekSlider(
            currentTime: currentTime,
            duration: duration,
            onSeek: onSeek,
            touchFriendly: true,
          ),
        ),
        const SizedBox(width: 8),
        for (var i = 0; i < pills.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          SizedBox(width: 64, child: pills[i]),
        ],
      ],
    );
  }

  Widget _buildTransport({required double playSize, bool includeStop = true}) {
    final skipButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 28,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          icon: const Icon(Icons.replay_5_rounded),
          tooltip: 'Back ${skipSeconds.toInt()} seconds',
          onPressed: () => _skip(-skipSeconds),
        ),
        const SizedBox(width: 4),
        IconButton.filled(
          iconSize: playSize * 0.55,
          constraints: BoxConstraints.tightFor(width: playSize, height: playSize),
          icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          tooltip: isPlaying ? 'Pause' : 'Play',
          onPressed: onPlayPause,
        ),
        const SizedBox(width: 4),
        IconButton(
          iconSize: 28,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          icon: const Icon(Icons.forward_5_rounded),
          tooltip: 'Forward ${skipSeconds.toInt()} seconds',
          onPressed: () => _skip(skipSeconds),
        ),
      ],
    );
    if (!includeStop) return skipButtons;

    return Row(
      children: [
        IconButton(
          iconSize: 26,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          icon: const Icon(Icons.skip_previous_rounded),
          tooltip: 'Back to start',
          onPressed: () => onSeek(0),
        ),
        Expanded(child: Center(child: skipButtons)),
        const SizedBox(width: 48), // balances the back-to-start button
      ],
    );
  }

  List<Widget> _buildPills(BuildContext context) {
    final rootName = noteNames[scaleRoot % 12];
    return [
      ControlPill(
        label: 'Speed',
        value: SpeedControl.format(playbackSpeed),
        isActive: playbackSpeed != 1.0,
        semanticsHint: 'Opens speed options',
        onTap: () => showSpeedSheet(
          context: context,
          speed: playbackSpeed,
          onChanged: onSpeedChanged,
        ),
      ),
      ControlPill(
        label: 'Key',
        value: formatSemitones(transposeAmount),
        isActive: transposeAmount != 0,
        semanticsHint: 'Opens key transpose options',
        onTap: () => showKeySheet(
          context: context,
          amount: transposeAmount,
          onChanged: onTransposeChanged,
        ),
      ),
      ControlPill(
        label: sargamEnabled ? 'Sa =' : 'Notes',
        value: sargamEnabled ? rootName : 'ABC',
        isActive: sargamEnabled,
        semanticsHint: 'Opens notation and tuning options',
        onTap: () => showNotationSheet(
          context: context,
          sargamEnabled: sargamEnabled,
          onSargamToggled: onSargamToggled,
          scaleRoot: scaleRoot,
          onScaleRootChanged: onScaleRootChanged,
          referenceFrequency: referenceFrequency,
          onReferenceFrequencyChanged: onReferenceFrequencyChange,
        ),
      ),
      ControlPill(
        label: 'Zoom',
        value: '${viewState.viewWindowSize.round()}s',
        semanticsHint: 'Opens zoom options',
        onTap: () => showViewSheet(
          context: context,
          viewState: viewState,
          maxTime: duration,
        ),
      ),
    ];
  }
}
