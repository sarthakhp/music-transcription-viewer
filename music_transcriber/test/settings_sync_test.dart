import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/job_settings.dart';
import 'package:music_transcriber/services/settings_sync_service.dart';

void main() {
  test('settings token matches the backend\'s uuid5', () {
    // Expected value computed with Python's uuid.uuid5 (what the backend uses).
    expect(
      settingsToken('c88cb993-b5af-4d09-96be-863b319e43cf'),
      'e089ef92-feb7-56f8-ba45-3c42f9d5bc36',
    );
  });

  test('JobSettings round-trips through JSON, including cloud fields', () {
    const original = JobSettings(
      playbackSpeed: 0.75,
      transposeAmount: -2,
      showBass: false,
      otherMinConfidence: 0.4,
      vocalDetail: 25,
      referenceFrequency: 442,
      track: 'vocal',
      updatedAtMs: 1234,
    );
    final copy = JobSettings.fromJson(original.toJson());
    expect(copy.toJson(), original.toJson());
  });

  test('older saved settings (no new fields) still load with defaults', () {
    final loaded = JobSettings.fromJson({'playbackSpeed': 1.5, 'transposeAmount': 3});
    expect(loaded.showVocals, isTrue);
    expect(loaded.vocalDetail, isNull);
    expect(loaded.updatedAtMs, 0);
  });
}
