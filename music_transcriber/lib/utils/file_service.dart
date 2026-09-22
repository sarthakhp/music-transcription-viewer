import 'dart:convert';
import 'dart:typed_data';
import '../models/pitch_data.dart';
import 'web_file_picker.dart';

/// Service for handling file operations
class FileService {
  /// Pick and parse a JSON pitch data file
  static Future<FilePickResult<ProcessedFramesData>> pickPitchDataFile() async {
    try {
      final result = await pickFileWeb(accept: 'application/json,.json', hint: 'json');
      if (result == null) return FilePickResult.cancelled();

      final jsonString = utf8.decode(result.bytes);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final pitchData = ProcessedFramesData.fromJson(jsonData);

      return FilePickResult.success(pitchData, result.name);
    } catch (e) {
      return FilePickResult.error('Failed to parse JSON: ${e.toString()}');
    }
  }

  /// Pick an audio file (MP3, WAV, etc.)
  static Future<FilePickResult<Uint8List>> pickAudioFile() async {
    try {
      const accept =
          'audio/mpeg,audio/wav,audio/flac,audio/mp4,audio/ogg,audio/webm,'
          '.mp3,.wav,.flac,.m4a,.ogg,.webm';
      final result = await pickFileWeb(accept: accept);
      if (result == null) return FilePickResult.cancelled();

      return FilePickResult.success(result.bytes, result.name);
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

