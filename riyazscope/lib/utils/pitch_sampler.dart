import '../models/pitch_data.dart';

/// Target number of pitch frames rendered per second.
/// Lower = fewer dots, better performance. Higher = more detail.
/// Change this single value to adjust display density globally.
const int kDisplayFramesPerSecond = 10;

/// Downsamples [frames] to at most [kDisplayFramesPerSecond] representative
/// frames per second.
///
/// The timeline is divided into fixed [1/kDisplayFramesPerSecond]-second buckets.
/// Within each bucket, consecutive frames sharing the same integer MIDI note are
/// collapsed into one (highest confidence wins). Frames with a different key from
/// their immediate neighbour are always kept, so pitch transitions are preserved.
///
/// Returns the original list unchanged if the source rate is already at or below
/// the target, avoiding any unnecessary work.
///
/// To disable compression entirely, replace the body with:
///   return frames;
List<PitchFrame> sampleDisplayFrames(
  List<PitchFrame> frames,
  double duration, {
  int framesPerSecond = kDisplayFramesPerSecond,
}) {
  if (duration <= 0 || frames.isEmpty) return frames;

  final sourceRate = frames.length / duration;
  if (sourceRate <= framesPerSecond) return frames;

  final bucketSize = 1.0 / framesPerSecond;
  final totalBuckets = (duration / bucketSize).ceil();
  final result = <PitchFrame>[];
  int frameIndex = 0;

  for (int b = 0; b < totalBuckets; b++) {
    final bucketStart = b * bucketSize;
    final bucketEnd = bucketStart + bucketSize;

    // Collect all frames in this bucket
    final bucketFrames = <PitchFrame>[];
    while (frameIndex < frames.length && frames[frameIndex].time < bucketEnd) {
      final frame = frames[frameIndex];
      if (frame.time >= bucketStart) bucketFrames.add(frame);
      frameIndex++;
    }

    if (bucketFrames.isEmpty) continue;

    // Collapse consecutive runs of the same integer MIDI note.
    // Keep the highest-confidence frame from each run; different keys are kept.
    int? currentKey;
    PitchFrame? bestInRun;

    for (final frame in bucketFrames) {
      final key = frame.midiPitch.round();
      if (key == currentKey) {
        if (frame.confidence > bestInRun!.confidence) bestInRun = frame;
      } else {
        if (bestInRun != null) result.add(bestInRun);
        currentKey = key;
        bestInRun = frame;
      }
    }
    if (bestInRun != null) result.add(bestInRun);
  }

  return result;
}
