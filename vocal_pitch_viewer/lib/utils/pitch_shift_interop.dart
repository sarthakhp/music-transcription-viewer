import 'dart:js_interop';

@JS('pitchShifter')
external _PitchShifterJS get _js;

extension type _PitchShifterJS._(JSObject _) implements JSObject {
  external void loadTrack(String blobUrl);
  external JSPromise setup();
  external JSPromise resume();
  external JSPromise play(String blobUrl);
  external void pause(String blobUrl);
  external void seek(String blobUrl, double seconds);
  external void setPitchSemitones(int semitones);
  external void reset();
}

void pitchShifterLoadTrack(String blobUrl) => _js.loadTrack(blobUrl);
Future<void> pitchShifterSetup() => _js.setup().toDart;
Future<void> pitchShifterResume() => _js.resume().toDart;
Future<void> pitchShifterPlay(String blobUrl) => _js.play(blobUrl).toDart;
void pitchShifterPause(String blobUrl) => _js.pause(blobUrl);
void pitchShifterSeek(String blobUrl, double seconds) =>
    _js.seek(blobUrl, seconds);
void pitchShifterSetSemitones(int semitones) => _js.setPitchSemitones(semitones);
void pitchShifterReset() => _js.reset();
