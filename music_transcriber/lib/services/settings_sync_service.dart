import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/job_settings.dart';

/// Syncs per-song settings with cloud storage so a song looks the same on
/// every device.
///
/// This is strictly a background concern: the app always applies and saves
/// settings locally first and never waits on this service. Every call here
/// swallows its own errors, so a missing network or cloud only means the
/// settings stay on this device.
///
/// - Local app: reads and writes through the backend, which holds the cloud
///   credentials.
/// - Hosted viewer: read-only, straight from the public object URL (the
///   browser holds no write credentials).
class SettingsSyncService {
  static const _pushDelay = Duration(seconds: 2);
  static const _timeout = Duration(seconds: 10);

  final http.Client _client;
  final Map<String, Timer> _timers = {};
  final Map<String, JobSettings> _pending = {};

  SettingsSyncService({http.Client? client}) : _client = client ?? http.Client();

  /// The settings stored in the cloud for [jobId], or null if there are none
  /// or the cloud can't be reached.
  Future<JobSettings?> fetch(String jobId) async {
    try {
      final response = ApiConfig.isRemote
          ? await _client.get(_publicUrl(jobId)).timeout(_timeout)
          : await _client
              .get(Uri.parse(ApiConfig.getUrl('/cloud/jobs/$jobId/settings')))
              .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      final data = ApiConfig.isRemote ? decoded : (decoded as Map)['settings'];
      if (data is! Map<String, dynamic>) return null;
      return JobSettings.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Queue [settings] to be stored in the cloud shortly after the last
  /// change. Returns immediately; later calls for the same song replace
  /// earlier ones.
  void schedulePush(String jobId, JobSettings settings) {
    if (ApiConfig.isRemote) return; // hosted viewer can't write
    _pending[jobId] = settings;
    _timers[jobId]?.cancel();
    _timers[jobId] = Timer(_pushDelay, () => _push(jobId));
  }

  /// Send any queued settings now (e.g. when leaving a song).
  void flush() {
    for (final jobId in _pending.keys.toList()) {
      _timers.remove(jobId)?.cancel();
      _push(jobId);
    }
  }

  Future<void> _push(String jobId) async {
    final settings = _pending.remove(jobId);
    _timers.remove(jobId);
    if (settings == null) return;
    try {
      await _client
          .put(
            Uri.parse(ApiConfig.getUrl('/cloud/jobs/$jobId/settings')),
            headers: {'Content-Type': 'application/json'},
            body: settings.toJsonString(),
          )
          .timeout(_timeout);
    } catch (_) {
      // Offline or cloud down: the next change queues a fresh push.
    }
  }

  /// Public URL of a song's settings object. The download token is derived
  /// from the job id (a version-5 UUID), matching the backend.
  Uri _publicUrl(String jobId) {
    final bucket = Uri.parse(ApiConfig.firebaseIndexUrl).pathSegments[2];
    return Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o/'
      'settings%2F$jobId.json?alt=media&token=${settingsToken(jobId)}',
    );
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _client.close();
  }
}

/// UUIDv5 of `music-transcription-settings:` plus the job id, in the URL namespace,
/// the same token the backend stamps on the settings object.
@visibleForTesting
String settingsToken(String jobId) {
  // RFC 4122 URL namespace.
  const namespace = [
    0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1,
    0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8,
  ];
  final digest = sha1
      .convert([...namespace, ...utf8.encode('music-transcription-settings:$jobId')])
      .bytes
      .sublist(0, 16);
  digest[6] = (digest[6] & 0x0f) | 0x50; // version 5
  digest[8] = (digest[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
