import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/widgets/graph_touch_gestures.dart';

void main() {
  group('PinchAxisResolver', () {
    late PinchAxisResolver resolver;
    setUp(() => resolver = PinchAxisResolver());

    test('stays undecided until the fingers have moved enough', () {
      expect(resolver.update(4, 2), PinchAxis.undecided);
      expect(resolver.update(-6, 3), PinchAxis.undecided);
    });

    test('a left-right spread zooms time only', () {
      expect(resolver.update(40, 6), PinchAxis.horizontal);
    });

    test('an up-down spread zooms pitch only', () {
      expect(resolver.update(5, -50), PinchAxis.vertical);
    });

    test('a diagonal pinch zooms both axes', () {
      expect(resolver.update(30, 25), PinchAxis.both);
    });

    test('pinching in is treated the same as spreading out', () {
      expect(resolver.update(-45, -4), PinchAxis.horizontal);
    });

    test('the choice is locked for the rest of the gesture', () {
      resolver.update(40, 2);
      expect(resolver.update(0, 200), PinchAxis.horizontal);
    });

    test('reset allows a new decision', () {
      resolver.update(40, 2);
      resolver.reset();
      expect(resolver.update(2, 40), PinchAxis.vertical);
    });
  });
}
