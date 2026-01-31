import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../services/audio_service.dart';
import '../../utils/filename_utils.dart';
import 'track_switcher.dart';

/// Toolbar widget for the viewer layout
class ViewerToolbar extends StatelessWidget {
  final AppState appState;
  final AudioService audioService;
  final AudioTrackType currentTrack;
  final bool isSwitchingTrack;
  final ValueChanged<AudioTrackType> onTrackChanged;
  final bool isNarrow;

  const ViewerToolbar({
    super.key,
    required this.appState,
    required this.audioService,
    required this.currentTrack,
    required this.isSwitchingTrack,
    required this.onTrackChanged,
    this.isNarrow = false,
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
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Right side: Controls
        Flexible(
          flex: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
          ],
        ),
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

