import 'dart:convert';
import 'dart:math';
import '../../models/audio_content_type.dart';

/// The shared shape of a submission in Cloud Storage, used by every client
/// (phone, website) so a worker sees the same thing whoever sent it:
///   `uploads/<id>/<file>`   the audio (absent for links)
///   `queue/<id>.json`       the request and, later, the worker's progress

String newRequestId([Random? random]) {
  final source = random ?? Random();
  return 'r${DateTime.now().millisecondsSinceEpoch}${source.nextInt(0xFFFF).toRadixString(16)}';
}

String uploadPath(String id, String fileName) => 'uploads/$id/$fileName';
String queuePath(String id) => 'queue/$id.json';

/// The queue entry a client writes. Workers add `status` updates afterwards.
String queueEntryJson({
  required String id,
  required String filename,
  required AudioContentType audioType,
  double? trimStart,
  double? trimEnd,
  String? sourceUrl,
  List<String> instruments = const [],
  String? notifyTopic,
  DateTime? now,
}) {
  return jsonEncode({
    'id': id,
    'filename': filename,
    'audio_type': audioType.apiValue,
    'source_url': ?sourceUrl,
    'trim_start': ?trimStart,
    'trim_end': ?trimEnd,
    // Left out when empty, so the worker decides on its own.
    'instruments': ?(instruments.isEmpty ? null : instruments),
    'notify_topic': ?notifyTopic,
    'status': 'queued',
    'created_at': (now ?? DateTime.now()).millisecondsSinceEpoch / 1000,
  });
}
