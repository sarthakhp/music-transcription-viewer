import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/view_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ViewState pinch zoom', () {
    late ViewState vs;
    setUp(() {
      vs = ViewState()..setBaseMidiRange(40, 80);
    });

    test('zoomXByFactor keeps the focal time fixed on screen', () {
      vs.setViewStartTime(20); // window is 30s: 20..50
      final focalTimeBefore = vs.viewStartTime + vs.viewWindowSize * 0.25;
      vs.zoomXByFactor(2.0, 0.25, maxTime: 200);
      expect(vs.viewWindowSize, closeTo(15, 1e-9));
      final focalTimeAfter = vs.viewStartTime + vs.viewWindowSize * 0.25;
      expect(focalTimeAfter, closeTo(focalTimeBefore, 1e-9));
    });

    test('zoomXByFactor clamps to the allowed window range', () {
      vs.zoomXByFactor(1000, 0.5, maxTime: 200);
      expect(vs.viewWindowSize, ViewState.minWindowSize);
      vs.zoomXByFactor(1 / 1000, 0.5, maxTime: 200);
      expect(vs.viewWindowSize, ViewState.maxWindowSize);
    });

    test('zoomYAtFocal keeps the focal pitch fixed on screen', () {
      const ratio = 0.3; // 30% down from the top
      double pitchAt(double r) =>
          vs.effectiveMaxMidi - r * (vs.effectiveMaxMidi - vs.effectiveMinMidi);
      final before = pitchAt(ratio);
      vs.zoomYAtFocal(2.0, ratio);
      expect(vs.yZoomScale, closeTo(2.0, 1e-9));
      expect(pitchAt(ratio), closeTo(before, 1e-9));
    });

    test('zoomYAtFocal clamps the zoom scale', () {
      vs.zoomYAtFocal(1000, 0.5);
      expect(vs.yZoomScale, ViewState.maxYZoomScale);
      vs.zoomYAtFocal(1 / 1000, 0.5);
      expect(vs.yZoomScale, ViewState.minYZoomScale);
    });

    test('panYByFraction moves the view by a fraction of its height', () {
      final span = vs.effectiveMaxMidi - vs.effectiveMinMidi;
      final topBefore = vs.effectiveMaxMidi;
      vs.panYByFraction(0.25);
      expect(vs.effectiveMaxMidi, closeTo(topBefore + span * 0.25, 1e-9));
    });

    test('isDefaultView tracks zoom and resets', () {
      expect(vs.isDefaultView, isTrue);
      vs.zoomYAtFocal(2.0, 0.5);
      expect(vs.isDefaultView, isFalse);
      vs.resetZoom();
      expect(vs.isDefaultView, isTrue);
    });
  });
}
