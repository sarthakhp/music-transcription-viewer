import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/pitch_data.dart';

/// Service for handling file operations
class FileService {
  /// Pick and parse a JSON pitch data file
  static Future<FilePickResult<ProcessedFramesData>> pickPitchDataFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return FilePickResult.cancelled();
      }

      final file = result.files.first;
      if (file.bytes == null) {
        return FilePickResult.error('Could not read file data');
      }

      final jsonString = utf8.decode(file.bytes!);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final pitchData = ProcessedFramesData.fromJson(jsonData);

      return FilePickResult.success(pitchData, file.name);
    } catch (e) {
      return FilePickResult.error('Failed to parse JSON: ${e.toString()}');
    }
  }

  /// Pick an audio file (MP3, WAV, etc.)
  static Future<FilePickResult<Uint8List>> pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'flac', 'm4a', 'ogg', 'webm'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return FilePickResult.cancelled();
      }

      final file = result.files.first;
      if (file.bytes == null) {
        return FilePickResult.error('Could not read file data');
      }

      return FilePickResult.success(file.bytes!, file.name);
    } catch (e) {
      return FilePickResult.error('Failed to load audio: ${e.toString()}');
    }
  }
}

/// Result of a file pick operation
class FilePickResult<T> {
  final T? data;
  final String? fileName;
  final String? error;
  final bool isCancelled;

  FilePickResult._({
    this.data,
    this.fileName,
    this.error,
    this.isCancelled = false,
  });

  factory FilePickResult.success(T data, String fileName) {
    return FilePickResult._(data: data, fileName: fileName);
  }

  factory FilePickResult.error(String message) {
    return FilePickResult._(error: message);
  }

  factory FilePickResult.cancelled() {
    return FilePickResult._(isCancelled: true);
  }

  bool get isSuccess => data != null && error == null && !isCancelled;
}

