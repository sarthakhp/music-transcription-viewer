import 'package:flutter/material.dart';
import '../../services/audio_service.dart';

/// Widget for switching between audio tracks (original, vocal, instrumental)
class TrackSwitcher extends StatelessWidget {
  final AudioService audioService;
  final AudioTrackType currentTrack;
  final bool isSwitching;
  final ValueChanged<AudioTrackType> onTrackChanged;
  final bool compact;

  const TrackSwitcher({
    super.key,
    required this.audioService,
    required this.currentTrack,
    required this.isSwitching,
    required this.onTrackChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Check if we have multiple tracks loaded
    int loadedTracks = 0;
    if (audioService.isTrackLoaded(AudioTrackType.original)) loadedTracks++;
    if (audioService.isTrackLoaded(AudioTrackType.vocal)) loadedTracks++;
    if (audioService.isTrackLoaded(AudioTrackType.instrumental)) loadedTracks++;

    if (loadedTracks <= 1) return const SizedBox.shrink();

    return Stack(
      alignment: Alignment.center,
      children: [
        SegmentedButton<AudioTrackType>(
          segments: [
            if (audioService.isTrackLoaded(AudioTrackType.original))
              ButtonSegment(
                value: AudioTrackType.original,
                label: compact ? null : const Text('Original'),
                icon: const Tooltip(
                  message: 'Original Mix',
                  child: Icon(Icons.music_note_rounded, size: 16),
                ),
              ),
            if (audioService.isTrackLoaded(AudioTrackType.vocal))
              ButtonSegment(
                value: AudioTrackType.vocal,
                label: compact ? null : const Text('Vocal'),
                icon: const Tooltip(
                  message: 'Vocal Only',
                  child: Icon(Icons.mic_rounded, size: 16),
                ),
              ),
            if (audioService.isTrackLoaded(AudioTrackType.instrumental))
              ButtonSegment(
                value: AudioTrackType.instrumental,
                label: compact ? null : const Text('Instrumental'),
                icon: const Tooltip(
                  message: 'Instrumental Only',
                  child: Icon(Icons.queue_music_rounded, size: 16),
                ),
              ),
          ],
          selected: {currentTrack},
          onSelectionChanged: isSwitching
              ? null
              : (selection) => onTrackChanged(selection.first),
          showSelectedIcon: false,
        ),
        if (isSwitching)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

