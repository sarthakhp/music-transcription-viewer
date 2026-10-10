/// What an uploaded recording contains. Mirrors the backend `audio_type`
/// field, which decides which processing stages run.
enum AudioContentType {
  /// Voice and instruments: separate them, then transcribe everything.
  mixed('mixed', 'Song', 'Separates vocals from music'),

  /// Voice only: skips separation, instruments and chords.
  vocals('vocals', 'Voice only', 'No separation, tracks the voice only'),

  /// Music only: skips separation and vocal pitch tracking.
  instrumental(
    'instrumental',
    'Music only',
    'No separation, tracks the instruments only',
  );

  const AudioContentType(this.apiValue, this.label, this.description);

  /// Value sent to and received from the backend.
  final String apiValue;
  final String label;
  final String description;

  /// Parses a backend value; unknown or missing values mean [mixed], which is
  /// what every job created before this option existed used.
  static AudioContentType fromApi(String? value) {
    return AudioContentType.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => AudioContentType.mixed,
    );
  }
}
