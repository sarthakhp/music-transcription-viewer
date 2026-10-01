/// No-op on platforms without the Media Session API.
class MediaSessionController {
  void attach({
    required String title,
    required void Function() onPlay,
    required void Function() onPause,
    required void Function(double seconds) onSeekTo,
    required void Function(double deltaSeconds) onSeekBy,
    required void Function() onRestart,
  }) {}

  void updateMetadata(String title) {}

  void updateState({
    required bool playing,
    required double position,
    required double duration,
    required double speed,
  }) {}

  void detach() {}
}
