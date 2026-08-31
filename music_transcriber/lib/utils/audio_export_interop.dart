import 'dart:js_interop';
import 'dart:typed_data';

@JS('audioExporter')
external _AudioExporterJS get _js;

extension type _AudioExporterJS._(JSObject _) implements JSObject {
  external JSPromise<JSUint8Array> exportMp3(
    JSArrayBuffer bytes,
    int semitones,
    num speed,
    JSFunction? onProgress,
  );
}

/// Renders [bytes] through an OfflineAudioContext with the given pitch/tempo
/// shift and encodes the result to MP3. Only modestly faster than real-time
/// (the SoundTouch worklet's DSP cost dominates), so [onProgress] (0..1) is
/// reported throughout rather than only at the end.
Future<Uint8List> jsExportMp3(
  Uint8List bytes, {
  required int semitones,
  required double speed,
  void Function(double progress)? onProgress,
}) async {
  final progressCallback = onProgress == null
      ? null
      : ((JSNumber fraction) => onProgress(fraction.toDartDouble)).toJS;
  final result = await _js
      .exportMp3(bytes.buffer.toJS, semitones, speed, progressCallback)
      .toDart;
  return result.toDart;
}
