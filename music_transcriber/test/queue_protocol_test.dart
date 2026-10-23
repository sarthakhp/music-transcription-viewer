import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/audio_content_type.dart';
import 'package:music_transcriber/services/cloud_upload/queue_protocol.dart';

void main() {
  final fixedTime = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);

  Map<String, dynamic> entry({String? url, double? start, double? end, String? topic}) =>
      jsonDecode(queueEntryJson(
        id: 'r1',
        filename: 'song.mp3',
        audioType: AudioContentType.vocals,
        sourceUrl: url,
        trimStart: start,
        trimEnd: end,
        notifyTopic: topic,
        now: fixedTime,
      )) as Map<String, dynamic>;

  test('a plain upload carries only what workers need', () {
    expect(entry(), {
      'id': 'r1',
      'filename': 'song.mp3',
      'audio_type': 'vocals',
      'status': 'queued',
      'created_at': 1_700_000_000.0,
    });
  });

  test('optional fields appear only when given', () {
    final full = entry(url: 'https://youtu.be/x', start: 1.5, end: 9, topic: 'n_abc');
    expect(full['source_url'], 'https://youtu.be/x');
    expect(full['trim_start'], 1.5);
    expect(full['trim_end'], 9);
    expect(full['notify_topic'], 'n_abc');
  });

  test('paths follow the layout the workers and storage rules expect', () {
    expect(uploadPath('r1', 'a b.mp3'), 'uploads/r1/a b.mp3');
    expect(queuePath('r1'), 'queue/r1.json');
  });

  test('request ids are unique enough and start with r', () {
    final ids = {for (var i = 0; i < 200; i++) newRequestId()};
    expect(ids.every((id) => id.startsWith('r')), isTrue);
    expect(ids.length, greaterThan(190));
  });
}
