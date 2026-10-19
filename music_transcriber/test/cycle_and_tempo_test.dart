import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/cycle_state.dart';
import 'package:music_transcriber/models/job_settings.dart';
import 'package:music_transcriber/screens/widgets/bpm_control.dart';

void main() {
  group('CycleState', () {
    test('setRegion orders, clamps and enforces a minimum length', () {
      final c = CycleState()..setRegion(12, 4, maxTime: 10, enabled: true);
      expect(c.start, 4);
      expect(c.end, 10);
      expect(c.active, isTrue);
      c.setRegion(3, 3.1, maxTime: 10);
      expect(c.end - c.start, CycleState.minLength);
    });

    test('moveTo keeps length and stays inside the song', () {
      final c = CycleState()..setRegion(2, 6, maxTime: 20);
      c.moveTo(18, maxTime: 20);
      expect(c.end, 20);
      expect(c.end - c.start, 4);
    });

    test('edges cannot cross', () {
      final c = CycleState()..setRegion(2, 6, maxTime: 20);
      c.setStart(9);
      expect(c.start, 6 - CycleState.minLength);
      c.setEnd(0, maxTime: 20);
      expect(c.end, c.start + CycleState.minLength);
    });

    test('restore ignores an invalid region', () {
      final c = CycleState()..restore(enabled: true, start: 5, end: 5);
      expect(c.hasRegion, isFalse);
      expect(c.enabled, isFalse);
    });
  });

  test('TapTempo averages recent intervals and restarts after a pause', () {
    final t = TapTempo();
    final t0 = DateTime(2026, 1, 1);
    expect(t.tap(t0), isNull);
    expect(t.tap(t0.add(const Duration(milliseconds: 500))), closeTo(120, 0.01));
    expect(t.tap(t0.add(const Duration(milliseconds: 1000))), closeTo(120, 0.01));
    expect(t.tap(t0.add(const Duration(seconds: 10))), isNull);
  });

  test('settings round-trip tempo override and cycle', () {
    const s = JobSettings(bpmOverride: 88.5, cycleEnabled: true, cycleStart: 3, cycleEnd: 9);
    final back = JobSettings.fromJson(s.toJson());
    expect(back.bpmOverride, 88.5);
    expect(back.cycleEnabled, isTrue);
    expect([back.cycleStart, back.cycleEnd], [3, 9]);
    expect(JobSettings.fromJson({}).bpmOverride, 0);
  });
}
