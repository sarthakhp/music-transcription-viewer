import 'dart:typed_data';

/// Offline MP3 export renders through Web Audio, which Android lacks.
Future<Uint8List> jsExportMp3(
  Uint8List bytes, {
  required int semitones,
  required double speed,
  void Function(double progress)? onProgress,
}) {
  throw UnsupportedError('MP3 export is only available on web');
}
