import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/audio_content_type.dart';
import '../models/job.dart';
import '../models/job_status.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import '../models/instrument_data.dart';
import '../utils/server_time.dart';
import 'cache/cached_fetcher.dart';
import 'cache/disk_cache.dart';
import 'cache/remote_index_store.dart';

/// Read-only data source for the hosted viewer.
///
/// Reads published artifacts directly from Firebase Storage public URLs:
///   index.json  → list of jobs (each with a manifest_url)
///   manifest.json → per-job metadata + file URLs (frames/chords/instruments/
///                   original/stems)
///
/// Everything is cached on the device (see services/cache): the song list and
/// manifests are shown from the saved copy and refreshed in the background;
/// pitch, chord and audio files are fetched once per URL. No backend is
/// involved, so create/cancel/delete/retry are unsupported here.
class RemoteDataSource {
  final http.Client _client;
  late final CachedFetcher _data;
  late final CachedFetcher _audio;
  late final RemoteIndexStore _indexStore;

  RemoteDataSource({http.Client? client}) : _client = client ?? http.Client() {
    _data = CachedFetcher(_client, const DiskCache('remote_data', maxBytes: 100 * 1024 * 1024),
        timeout: ApiConfig.requestTimeout);
    _audio = CachedFetcher(_client, const DiskCache('remote_audio', maxBytes: 500 * 1024 * 1024),
        timeout: ApiConfig.downloadTimeout);
    _indexStore = RemoteIndexStore(_data);
  }

  final Map<String, Map<String, dynamic>> _manifests = {}; // jobId -> manifest

  /// Fires when a background refresh finds a changed song list.
  Stream<void> get libraryUpdates => _indexStore.updates;

  Future<Map<String, dynamic>> _loadIndex() => _indexStore.load();

  Map<String, dynamic>? _summaryFor(String jobId) {
    final jobs = (_indexStore.current?['jobs'] as List<dynamic>?) ?? const [];
    for (final j in jobs) {
      if (j is Map<String, dynamic> && j['id'] == jobId) return j;
    }
    return null;
  }

  Future<Map<String, dynamic>> _loadManifest(String jobId) async {
    final cached = _manifests[jobId];
    if (cached != null) return cached;

    await _loadIndex();
    final summary = _summaryFor(jobId);
    final manifestUrl = summary?['manifest_url'] as String?;
    if (manifestUrl == null) {
      throw Exception('No manifest URL for job $jobId');
    }
    final manifest = await _readManifest(manifestUrl);
    _manifests[jobId] = manifest;
    return manifest;
  }

  /// Manifests can change in place (a rename), so the saved copy is used for
  /// speed and a fresh one replaces it in memory a moment later.
  Future<Map<String, dynamic>> _readManifest(String url) async {
    final saved = await _data.peek(url);
    if (saved == null) return _decode(await _data.getFresh(url));
    unawaited(_data.getFresh(url).then((bytes) {
      final fresh = _decode(bytes);
      final id = fresh['id'] as String?;
      if (id != null) _manifests[id] = fresh;
    }).catchError((_) {}));
    return _decode(saved);
  }

  Map<String, dynamic> _decode(Uint8List bytes) =>
      json.decode(utf8.decode(bytes)) as Map<String, dynamic>;

  String? _fileUrl(Map<String, dynamic> manifest, String key) {
    final files = manifest['files'] as Map<String, dynamic>?;
    return files?[key] as String?;
  }

  // ---- Read API (mirrors TranscriptionApiService method shapes) ----

  /// Completed jobs from index.json. Any non-'completed' status (e.g. the
  /// 'failed' query the home screen makes) yields an empty list — the hosted
  /// viewer only ever shows finished work.
  ///
  /// Served from the saved copy when there is one; pass [fresh] to wait for the
  /// latest list from the network instead.
  Future<ApiResponse<JobListResponse>> listJobs({String? status, bool fresh = false}) async {
    if (status != null && status != 'completed') {
      return ApiResponse.success(const JobListResponse(jobs: []));
    }
    try {
      final index = fresh ? await _indexStore.refresh() : await _loadIndex();
      final jobs = ((index['jobs'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_summaryToJobListItem)
          .toList();
      return ApiResponse.success(JobListResponse(jobs: jobs));
    } catch (e) {
      return ApiResponse.error('Failed to load jobs: $e');
    }
  }

  Future<ApiResponse<JobResultsSummary>> getJobResults(String jobId) async {
    try {
      final m = await _loadManifest(jobId);
      final title = (m['title'] ?? m['input_filename'] ?? 'Untitled') as String;
      return ApiResponse.success(JobResultsSummary(
        jobId: jobId,
        status: JobStatus.completed,
        progress: 100,
        inputFilename: (m['input_filename'] ?? title) as String,
        duration: _toDouble(m['duration']),
        tempoBpm: _toDouble(m['tempo_bpm']),
        stems: ((m['stems'] as List<dynamic>?) ?? const []).cast<String>(),
        framesAvailable: _fileUrl(m, 'frames') != null,
        chordsAvailable: _fileUrl(m, 'chords') != null,
        numFrames: _toInt(m['num_frames']),
        numChords: _toInt(m['num_chords']),
        processingTime: 0,
        sourceType: m['source_type'] as String?,
        sourceUrl: m['source_url'] as String?,
        videoTitle: m['title'] as String?,
        userDisplayName: m['display_name'] as String?,
        audioType: AudioContentType.fromApi(m['audio_type'] as String?),
      ));
    } catch (e) {
      return ApiResponse.error('Failed to load job results: $e');
    }
  }

  Future<ApiResponse<ProcessedFramesData>> getFrames(String jobId) async {
    return _fetchJson(jobId, 'frames', (body) async =>
        await compute(_parseFrames, body));
  }

  Future<ApiResponse<ChordData>> getChords(String jobId) async {
    return _fetchJson(jobId, 'chords',
        (body) async => ChordData.fromJson(json.decode(body) as Map<String, dynamic>));
  }

  Future<ApiResponse<InstrumentData>> getInstruments(String jobId) async {
    return _fetchJson(jobId, 'instruments',
        (body) async => InstrumentData.fromJson(json.decode(body) as Map<String, dynamic>));
  }

  Future<ApiResponse<T>> _fetchJson<T>(
    String jobId,
    String key,
    Future<T> Function(String body) parse,
  ) async {
    try {
      final m = await _loadManifest(jobId);
      final url = _fileUrl(m, key);
      if (url == null) {
        return ApiResponse.error('$key not available for job $jobId', statusCode: 404);
      }
      final bytes = await _data.getImmutable(url);
      return ApiResponse.success(await parse(utf8.decode(bytes)));
    } catch (e) {
      return ApiResponse.error('Failed to fetch $key: $e');
    }
  }

  Future<ApiResponse<Uint8List>> downloadStem({
    required String jobId,
    required String stemName,
  }) async {
    try {
      final m = await _loadManifest(jobId);
      String? url;
      if (stemName == 'original') {
        url = _fileUrl(m, 'original');
      } else {
        final stems = (m['files'] as Map<String, dynamic>?)?['stems']
            as Map<String, dynamic>?;
        url = stems?[stemName] as String?;
      }
      if (url == null) {
        return ApiResponse.error('Stem "$stemName" not available', statusCode: 404);
      }
      return ApiResponse.success(await _audio.getImmutable(url));
    } catch (e) {
      return ApiResponse.error('Failed to download $stemName: $e');
    }
  }

  JobListItem _summaryToJobListItem(Map<String, dynamic> s) {
    final title = (s['title'] ?? 'Untitled') as String;
    DateTime created;
    try {
      created = parseServerTime(s['created_at'] as String);
    } catch (_) {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return JobListItem(
      id: s['id'] as String,
      status: JobStatus.completed,
      progress: 100,
      createdAt: created,
      inputFilename: title,
      fileSize: 0,
      duration: _toDouble(s['duration']),
      tempoBpm: _toDouble(s['tempo_bpm']),
      numFrames: 0,
      numChords: _toInt(s['num_chords']),
      sourceType: s['source_type'] as String?,
      sourceUrl: s['source_url'] as String?,
      videoTitle: title,
      userDisplayName: s['display_name'] as String?,
      audioType: AudioContentType.fromApi(s['audio_type'] as String?),
    );
  }

  void dispose() {
    _indexStore.dispose();
    _client.close();
  }
}

double _toDouble(dynamic v) => v is num ? v.toDouble() : 0.0;
int _toInt(dynamic v) => v is num ? v.toInt() : 0;

/// Top-level for compute() isolate parsing of the (large) frames JSON.
ProcessedFramesData _parseFrames(String body) =>
    ProcessedFramesData.fromJson(json.decode(body) as Map<String, dynamic>);
