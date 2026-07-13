import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';
import 'transcription_api_service.dart';

/// Service for handling audio file uploads with progress tracking
class UploadService {
  final TranscriptionApiService _apiService;
  final AppState _appState;

  UploadService({
    required TranscriptionApiService apiService,
    required AppState appState,
  })  : _apiService = apiService,
        _appState = appState;

  /// Upload an audio file and update app state
  /// Returns the job ID on success, or null on failure
  Future<String?> uploadAudioFile({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      // Validate file before upload
      final validationError = _validateFile(fileBytes, fileName);
      if (validationError != null) {
        _appState.failJob(validationError);
        return null;
      }

      // Start upload
      _appState.startUpload();

      // Perform upload
      final response = await _apiService.uploadAudioFile(
        fileBytes: fileBytes,
        fileName: fileName,
      );

      // Handle response
      if (response.isSuccess) {
        final jobId = response.data!.jobId;
        _appState.completeUpload(jobId);
        return jobId;
      } else {
        _appState.failJob(response.error ?? 'Upload failed');
        return null;
      }
    } catch (e) {
      _appState.failJob('Upload error: ${e.toString()}');
      return null;
    }
  }

  /// Validate file before upload
  String? _validateFile(Uint8List fileBytes, String fileName) {
    // Check file size (100MB max)
    const maxSizeBytes = 100 * 1024 * 1024; // 100MB
    if (fileBytes.length > maxSizeBytes) {
      return 'File too large. Maximum size is 100MB.';
    }

    // Check file extension
    final extension = fileName.toLowerCase().split('.').last;
    const supportedFormats = ['mp3', 'wav', 'flac', 'm4a', 'ogg', 'webm'];
    if (!supportedFormats.contains(extension)) {
      return 'Unsupported format. Supported: ${supportedFormats.join(', ')}';
    }

    return null; // Valid
  }

  /// Get formatted file size
  String getFormattedFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Check if file format is supported
  bool isSupportedFormat(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    const supportedFormats = ['mp3', 'wav', 'flac', 'm4a', 'ogg', 'webm'];
    return supportedFormats.contains(extension);
  }

  /// Get file extension
  String getFileExtension(String fileName) {
    return fileName.split('.').last.toLowerCase();
  }
}

