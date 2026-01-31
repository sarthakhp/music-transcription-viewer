import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/job.dart';
import '../models/job_status.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import '../utils/api_error_handler.dart';

/// Main API service for Music Transcription backend
class TranscriptionApiService {
  final http.Client _client;

  TranscriptionApiService({http.Client? client})
      : _client = client ?? http.Client();

  /// Get common headers for all requests (includes ngrok bypass header)
  Map<String, String> get _commonHeaders => {
    'ngrok-skip-browser-warning': 'true',
  };

  // ========== Endpoint 1: Upload Audio File ==========

  /// Upload an audio file to start processing
  /// POST /api/v1/transcribe
  Future<ApiResponse<JobCreationResponse>> uploadAudioFile({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.getUrl(ApiConfig.transcribeEndpoint));

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_commonHeaders);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send()
          .timeout(ApiConfig.uploadTimeout);
      
      final response = await http.Response.fromStream(streamedResponse);

      return ApiErrorHandler.handleResponse(
        response,
        (json) => JobCreationResponse.fromJson(json),
      );
    } catch (e) {
      return ApiErrorHandler.handleException(e);
    }
  }

  // ========== Endpoint 2: Get Job Status ==========

  /// Get job status for polling
  /// GET /api/v1/jobs/{job_id}/status
  Future<ApiResponse<JobStatusResponse>> getJobStatus(String jobId) async {
    return ApiErrorHandler.executeApiCall(
      () => _client.get(
        Uri.parse(ApiConfig.getUrl('${ApiConfig.jobsEndpoint}/$jobId/status')),
        headers: _commonHeaders,
      ).timeout(ApiConfig.requestTimeout),
      (json) => JobStatusResponse.fromJson(json),
    );
  }

  // ========== Endpoint 3: Get Job Results Summary ==========

  /// Get aggregated results and availability flags
  /// GET /api/v1/jobs/{job_id}/results
  Future<ApiResponse<JobResultsSummary>> getJobResults(String jobId) async {
    return ApiErrorHandler.executeApiCall(
      () => _client.get(
        Uri.parse(ApiConfig.getUrl('${ApiConfig.jobsEndpoint}/$jobId/results')),
        headers: _commonHeaders,
      ).timeout(ApiConfig.requestTimeout),
      (json) => JobResultsSummary.fromJson(json),
    );
  }

  // ========== Endpoint 4: List Available Stems ==========

  /// Get list of separated audio stems
  /// GET /api/v1/jobs/{job_id}/stems
  Future<ApiResponse<StemsListResponse>> listStems(String jobId) async {
    return ApiErrorHandler.executeApiCall(
      () => _client.get(
        Uri.parse(ApiConfig.getUrl('${ApiConfig.jobsEndpoint}/$jobId/stems')),
        headers: _commonHeaders,
      ).timeout(ApiConfig.requestTimeout),
      (json) => StemsListResponse.fromJson(json),
    );
  }

  // ========== Endpoint 5: Download Stem ==========

  /// Download a specific separated stem or original audio
  /// GET /api/v1/jobs/{job_id}/stems/{stem_name}
  /// stem_name: vocals, bass, drums, other, instrumental, original
  Future<ApiResponse<Uint8List>> downloadStem({
    required String jobId,
    required String stemName,
  }) async {
    return ApiErrorHandler.executeBinaryApiCall(
      () => _client.get(
        Uri.parse(ApiConfig.getUrl('${ApiConfig.jobsEndpoint}/$jobId/stems/$stemName')),
        headers: _commonHeaders,
      ).timeout(ApiConfig.downloadTimeout),
    ).then((response) => response.map((bytes) => Uint8List.fromList(bytes)));
  }

  // ========== Endpoint 6: Get Processed Frames ==========

  /// Get pitch detection data (10ms intervals)
  /// GET /api/v1/jobs/{job_id}/frames
  /// Uses isolate-based parsing to avoid blocking the main thread with large JSON
  Future<ApiResponse<ProcessedFramesData>> getFrames(String jobId) async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConfig.getUrl('${ApiConfig.jobsEndpoint}/$jobId/frames')),
        headers: _commonHeaders,
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Parse entire JSON and create ProcessedFramesData in isolate
        final data = await compute(_parseProcessedFramesData, response.body);
        return ApiResponse.success(data, statusCode: response.statusCode);
      }

      // Handle error response
      return ApiResponse.error(
        'Failed to fetch frames: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiErrorHandler.handleException(e);
    }
  }

  // ========== Endpoint 7: Get Chords ==========

  /// Get detected chord progression
  /// GET /api/v1/jobs/{job_id}/chords
  Future<ApiResponse<ChordData>> getChords(String jobId) async {
    return ApiErrorHandler.executeApiCall(
      () => _client.get(
        Uri.parse(ApiConfig.getUrl('${ApiConfig.jobsEndpoint}/$jobId/chords')),
        headers: _commonHeaders,
      ).timeout(ApiConfig.requestTimeout),
      (json) => ChordData.fromJson(json),
    );
  }

  // ========== Endpoint 8: Delete Job ==========

  /// Delete job and all associated files
  /// DELETE /api/v1/jobs/{job_id}
  Future<ApiResponse<JobDeletionResponse>> deleteJob(String jobId) async {
    return ApiErrorHandler.executeApiCall(
      () => _client.delete(
        Uri.parse(ApiConfig.getUrl('${ApiConfig.jobsEndpoint}/$jobId')),
        headers: _commonHeaders,
      ).timeout(ApiConfig.requestTimeout),
      (json) => JobDeletionResponse.fromJson(json),
    );
  }

  // ========== Endpoint 9: Health Check ==========

  /// Check API health and queue status
  /// GET /health
  Future<ApiResponse<HealthCheckResponse>> healthCheck() async {
    return ApiErrorHandler.executeApiCall(
      () => _client.get(
        Uri.parse(ApiConfig.healthUrl),
        headers: _commonHeaders,
      ).timeout(ApiConfig.requestTimeout),
      (json) => HealthCheckResponse.fromJson(json),
    );
  }

  // ========== Endpoint 10: List Jobs ==========

  /// List jobs with optional status filter
  /// GET /api/v1/jobs?status={status}
  Future<ApiResponse<JobListResponse>> listJobs({String? status}) async {
    final uri = Uri.parse(ApiConfig.getUrl(ApiConfig.jobsEndpoint));
    final uriWithParams = status != null
        ? uri.replace(queryParameters: {'status': status})
        : uri;

    return ApiErrorHandler.executeApiCall(
      () => _client.get(uriWithParams, headers: _commonHeaders).timeout(ApiConfig.requestTimeout),
      (json) => JobListResponse.fromJson(json),
    );
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }

  // ========== Helper Methods ==========

  /// Poll job status until completion or failure
  /// Returns the final status response
  Future<ApiResponse<JobStatusResponse>> pollUntilComplete({
    required String jobId,
    Duration? pollingInterval,
    int? maxAttempts,
    void Function(JobStatusResponse status)? onProgress,
  }) async {
    final interval = pollingInterval ?? ApiConfig.pollingInterval;
    final maxPoll = maxAttempts ?? ApiConfig.maxPollingAttempts;

    int attempts = 0;

    while (attempts < maxPoll) {
      final response = await getJobStatus(jobId);

      if (!response.isSuccess) {
        return response;
      }

      final status = response.data!;

      // Notify progress callback
      if (onProgress != null) {
        onProgress(status);
      }

      // Check if job is complete or failed
      if (status.status.isTerminal) {
        return response;
      }

      // Wait before next poll
      await Future.delayed(interval);
      attempts++;
    }

    return ApiResponse.error('Polling timeout: Job did not complete within expected time');
  }

  /// Download all required stems for the UI (original, vocals, instrumental)
  Future<Map<String, ApiResponse<Uint8List>>> downloadAllStems(String jobId) async {
    final results = <String, ApiResponse<Uint8List>>{};

    // Download in parallel
    final futures = await Future.wait([
      downloadStem(jobId: jobId, stemName: 'original'),
      downloadStem(jobId: jobId, stemName: 'vocals'),
      downloadStem(jobId: jobId, stemName: 'instrumental'),
    ]);

    results['original'] = futures[0];
    results['vocals'] = futures[1];
    results['instrumental'] = futures[2];

    return results;
  }

  /// Get all processed data (frames + chords) in one call
  Future<({
    ApiResponse<ProcessedFramesData> frames,
    ApiResponse<ChordData> chords,
  })> getAllProcessedData(String jobId) async {
    final results = await Future.wait([
      getFrames(jobId),
      getChords(jobId),
    ]);

    return (
      frames: results[0] as ApiResponse<ProcessedFramesData>,
      chords: results[1] as ApiResponse<ChordData>,
    );
  }

  /// Complete workflow: Upload → Poll → Get Data
  /// Returns all data needed for visualization
  Future<ApiResponse<CompleteJobData>> processAudioFile({
    required Uint8List fileBytes,
    required String fileName,
    void Function(JobStatusResponse status)? onProgress,
  }) async {
    // Step 1: Upload
    final uploadResponse = await uploadAudioFile(
      fileBytes: fileBytes,
      fileName: fileName,
    );

    if (!uploadResponse.isSuccess) {
      return ApiResponse.error(uploadResponse.error!);
    }

    final jobId = uploadResponse.data!.jobId;

    // Step 2: Poll until complete
    final statusResponse = await pollUntilComplete(
      jobId: jobId,
      onProgress: onProgress,
    );

    if (!statusResponse.isSuccess) {
      return ApiResponse.error(statusResponse.error!);
    }

    if (statusResponse.data!.hasFailed) {
      return ApiResponse.error(
        statusResponse.data!.errorMessage ?? 'Job processing failed',
      );
    }

    // Step 3: Get all data
    final data = await getAllProcessedData(jobId);
    final stems = await downloadAllStems(jobId);

    // Check for errors
    if (!data.frames.isSuccess) {
      return ApiResponse.error('Failed to fetch frames: ${data.frames.error}');
    }
    if (!data.chords.isSuccess) {
      return ApiResponse.error('Failed to fetch chords: ${data.chords.error}');
    }

    return ApiResponse.success(CompleteJobData(
      jobId: jobId,
      frames: data.frames.data!,
      chords: data.chords.data!,
      originalAudio: stems['original']!.data,
      vocalAudio: stems['vocals']!.data,
      instrumentalAudio: stems['instrumental']!.data,
    ));
  }
}

/// Complete job data for visualization
class CompleteJobData {
  final String jobId;
  final ProcessedFramesData frames;
  final ChordData chords;
  final Uint8List? originalAudio;
  final Uint8List? vocalAudio;
  final Uint8List? instrumentalAudio;

  const CompleteJobData({
    required this.jobId,
    required this.frames,
    required this.chords,
    this.originalAudio,
    this.vocalAudio,
    this.instrumentalAudio,
  });

  /// Check if all audio stems are available
  bool get hasAllAudio =>
      originalAudio != null &&
      vocalAudio != null &&
      instrumentalAudio != null;
}

/// Top-level function for parsing ProcessedFramesData in isolate
/// This MUST be a top-level function to work with compute()
/// Parses JSON string and creates ProcessedFramesData object
ProcessedFramesData _parseProcessedFramesData(String jsonString) {
  final jsonData = json.decode(jsonString) as Map<String, dynamic>;
  return ProcessedFramesData.fromJson(jsonData);
}
