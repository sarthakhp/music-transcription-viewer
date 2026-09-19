import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../services/audio_service.dart';
import '../../utils/filename_utils.dart';
import 'display_settings_popover.dart';
import 'track_switcher.dart';

// Colors matching instrument_renderer.dart
import '../../theme/app_palette.dart';

/// Toolbar widget for the viewer layout
class ViewerToolbar extends StatelessWidget {
  final AppState appState;
  final AudioService audioService;
  final AudioTrackType currentTrack;
  final bool isSwitchingTrack;
  final ValueChanged<AudioTrackType> onTrackChanged;
  final bool isNarrow;

  // Layer visibility
  final bool showVocals;
  final bool showBass;
  final bool showOther;
  final ValueChanged<bool> onVocalsToggled;
  final ValueChanged<bool> onBassToggled;
  final ValueChanged<bool> onOtherToggled;

  // Confidence thresholds
  final double vocalsMinConfidence;
  final double bassMinConfidence;
  final double otherMinConfidence;
  final ValueChanged<double> onVocalsConfidenceChanged;
  final ValueChanged<double> onBassConfidenceChanged;
  final ValueChanged<double> onOtherConfidenceChanged;

  // Vocal detail (frames per second)
  final int vocalDetail;
  final ValueChanged<int> onVocalDetailChanged;

  // Rename callback — null when no job is active (e.g. remote/Firebase mode)
  final String? currentJobId;
  final Future<void> Function(String jobId, String newName)? onJobRenamed;

  const ViewerToolbar({
    super.key,
    required this.appState,
    required this.audioService,
    required this.currentTrack,
    required this.isSwitchingTrack,
    required this.onTrackChanged,
    this.isNarrow = false,
    this.showVocals = true,
    this.showBass = true,
    this.showOther = true,
    required this.onVocalsToggled,
    required this.onBassToggled,
    required this.onOtherToggled,
    this.vocalsMinConfidence = 0.0,
    this.bassMinConfidence = 0.0,
    this.otherMinConfidence = 0.0,
    required this.onVocalsConfidenceChanged,
    required this.onBassConfidenceChanged,
    required this.onOtherConfidenceChanged,
    this.vocalDetail = 10,
    required this.onVocalDetailChanged,
    this.currentJobId,
    this.onJobRenamed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: isNarrow
          ? _buildNarrowToolbar(context, theme, colorScheme)
          : _buildWideToolbar(context, theme, colorScheme),
    );
  }

  Widget _buildWideToolbar(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        // Left side: Audio file info and metadata - wraps when narrow
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.audiotrack_rounded, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                _EditableFilename(
                  filename: appState.audioFileName ?? 'Audio',
                  onRenamed: (newName) {
                    appState.renameAudioFile(newName);
                    if (currentJobId != null && onJobRenamed != null) {
                      onJobRenamed!(currentJobId!, newName);
                    }
                  },
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(appState.pitchData?.durationFormatted ?? '', style: theme.textTheme.bodySmall),
                if (appState.pitchData?.metadata.bpm != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.speed_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text('${appState.pitchData?.metadata.bpm?.toStringAsFixed(1)} BPM', style: theme.textTheme.bodySmall),
                ],
                if (appState.chordData != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.music_note_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text('${appState.chordData!.uniqueChordsCount} chords', style: theme.textTheme.bodySmall),
                ],
                if (appState.instrumentData != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.piano_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text('${appState.instrumentData!.totalNotes} notes', style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Right side: Layer toggles + track switcher - always visible
        _buildLayerToggles(colorScheme),
        const SizedBox(width: 8),
        TrackSwitcher(
          audioService: audioService,
          currentTrack: currentTrack,
          isSwitching: isSwitchingTrack,
          onTrackChanged: onTrackChanged,
          compact: true,
        ),
      ],
    );
  }

  Widget _buildNarrowToolbar(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Metadata chips row
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            if (appState.pitchData != null)
              _buildMetaChip(Icons.timer_outlined, appState.pitchData!.durationFormatted, colorScheme),
            if (appState.pitchData?.metadata.bpm != null)
              _buildMetaChip(Icons.speed_rounded, '${appState.pitchData!.metadata.bpm!.toStringAsFixed(0)} BPM', colorScheme),
            if (appState.chordData != null)
              _buildMetaChip(Icons.music_note_rounded, '${appState.chordData!.uniqueChordsCount} chords', colorScheme),
            if (appState.instrumentData != null)
              _buildMetaChip(Icons.piano_rounded, '${appState.instrumentData!.totalNotes} notes', colorScheme),
          ],
        ),
        // Layer toggles
        _buildLayerToggles(colorScheme),
        // Track switcher row — compact (icon-only) so segment labels don't
        // wrap mid-word when squeezed into a narrow width.
        TrackSwitcher(
          audioService: audioService,
          currentTrack: currentTrack,
          isSwitching: isSwitchingTrack,
          onTrackChanged: onTrackChanged,
          compact: true,
        ),
      ],
    );
  }

  Widget _buildLayerToggles(ColorScheme colorScheme) {
    final hasInstruments = appState.instrumentData != null;
    final hasBass = appState.instrumentData?.bass != null;
    final hasOther = appState.instrumentData?.other != null;

    // Only show the toggles section if there's something to toggle
    if (!hasInstruments) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Layers:',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        _LayerChip(
          label: 'Vocals',
          color: colorScheme.primary,
          selected: showVocals,
          onToggled: onVocalsToggled,
        ),
        if (hasBass) ...[
          const SizedBox(width: 4),
          _LayerChip(
            label: 'Bass',
            color: appPalette.bassColor,
            selected: showBass,
            onToggled: onBassToggled,
          ),
        ],
        if (hasOther) ...[
          const SizedBox(width: 4),
          _LayerChip(
            label: 'Other',
            color: appPalette.otherColor,
            selected: showOther,
            onToggled: onOtherToggled,
          ),
        ],
        const SizedBox(width: 6),
        DisplaySettingsButton(
          hasInstruments: hasInstruments,
          hasBass: hasBass,
          hasOther: hasOther,
          vocalsMinConfidence: vocalsMinConfidence,
          bassMinConfidence: bassMinConfidence,
          otherMinConfidence: otherMinConfidence,
          onVocalsConfidenceChanged: onVocalsConfidenceChanged,
          onBassConfidenceChanged: onBassConfidenceChanged,
          onOtherConfidenceChanged: onOtherConfidenceChanged,
          vocalDetail: vocalDetail,
          onVocalDetailChanged: onVocalDetailChanged,
        ),
      ],
    );
  }

  Widget _buildMetaChip(IconData icon, String text, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.7))),
      ],
    );
  }
}

/// Compact toggle chip for a single layer with a colored dot indicator
class _LayerChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onToggled;

  const _LayerChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onToggled(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.6) : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected ? color : color.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline-editable filename label. Click/tap to edit; Enter or blur to confirm.
/// Changes are local only — no backend or Firebase writes.
class _EditableFilename extends StatefulWidget {
  final String filename;
  final ValueChanged<String> onRenamed;

  const _EditableFilename({required this.filename, required this.onRenamed});

  @override
  State<_EditableFilename> createState() => _EditableFilenameState();
}

class _EditableFilenameState extends State<_EditableFilename> {
  bool _editing = false;
  late TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.filename);
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void didUpdateWidget(_EditableFilename old) {
    super.didUpdateWidget(old);
    if (!_editing && old.filename != widget.filename) {
      _ctrl.text = widget.filename;
    }
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _ctrl.text = widget.filename;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    });
  }

  void _commit() {
    final val = _ctrl.text.trim();
    if (val.isNotEmpty) widget.onRenamed(val);
    setState(() => _editing = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_editing) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 80, maxWidth: 220),
        child: IntrinsicWidth(
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            style: theme.textTheme.bodySmall,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              border: UnderlineInputBorder(),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      );
    }
    return Tooltip(
      message: '${widget.filename}\n(click to rename)',
      child: GestureDetector(
        onTap: _startEditing,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  FilenameUtils.shortenFilename(widget.filename),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_rounded, size: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}
