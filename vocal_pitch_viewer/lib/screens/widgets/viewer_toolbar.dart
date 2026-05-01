import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../services/audio_service.dart';
import '../../utils/filename_utils.dart';
import 'display_settings_popover.dart';
import 'track_switcher.dart';

// Colors matching instrument_renderer.dart
const Color _bassColor = Color(0xFFFF6B35);
const Color _otherColor = Color(0xFF48BFE3);

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
        // Left side: Audio file info and metadata
        Flexible(
          flex: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.audiotrack_rounded, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Tooltip(
                  message: appState.audioFileName ?? 'Audio',
                  child: Text(
                    FilenameUtils.shortenFilename(appState.audioFileName ?? 'Audio'),
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer_outlined, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(appState.pitchData!.durationFormatted, style: theme.textTheme.bodySmall),
              if (appState.pitchData!.metadata.bpm != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.speed_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text('${appState.pitchData!.metadata.bpm!.toStringAsFixed(1)} BPM', style: theme.textTheme.bodySmall),
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
        const SizedBox(width: 8),
        // Right side: Layer toggles + track switcher
        Flexible(
          flex: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLayerToggles(colorScheme),
              const SizedBox(width: 8),
              Flexible(
                child: TrackSwitcher(
                  audioService: audioService,
                  currentTrack: currentTrack,
                  isSwitching: isSwitchingTrack,
                  onTrackChanged: onTrackChanged,
                  compact: true,
                ),
              ),
            ],
          ),
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
            _buildMetaChip(Icons.timer_outlined, appState.pitchData!.durationFormatted, colorScheme),
            if (appState.pitchData!.metadata.bpm != null)
              _buildMetaChip(Icons.speed_rounded, '${appState.pitchData!.metadata.bpm!.toStringAsFixed(0)} BPM', colorScheme),
            if (appState.chordData != null)
              _buildMetaChip(Icons.music_note_rounded, '${appState.chordData!.uniqueChordsCount} chords', colorScheme),
            if (appState.instrumentData != null)
              _buildMetaChip(Icons.piano_rounded, '${appState.instrumentData!.totalNotes} notes', colorScheme),
          ],
        ),
        // Layer toggles
        _buildLayerToggles(colorScheme),
        // Track switcher row
        TrackSwitcher(
          audioService: audioService,
          currentTrack: currentTrack,
          isSwitching: isSwitchingTrack,
          onTrackChanged: onTrackChanged,
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
            color: _bassColor,
            selected: showBass,
            onToggled: onBassToggled,
          ),
        ],
        if (hasOther) ...[
          const SizedBox(width: 4),
          _LayerChip(
            label: 'Other',
            color: _otherColor,
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
