import 'dart:typed_data';
import '../../models/audio_content_type.dart';
import 'queue_status.dart';

/// Used where uploading isn't available (the Mac app and local browser, which
/// talk to the local backend instead).
class CloudUpload {
  static bool get isSupported => false;

  Future<String?> signedInEmail() async => null;
  Future<String> signIn() => throw UnsupportedError('Upload is not available here');
  Future<void> signOut() async {}

  Future<String> submit({
    required String path,
    required String fileName,
    required AudioContentType audioType,
    double? trimStart,
    double? trimEnd,
    List<String> instruments = const [],
    void Function(double fraction)? onProgress,
  }) =>
      throw UnsupportedError('Upload is not available here');

  Future<String> submitBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required AudioContentType audioType,
    double? trimStart,
    double? trimEnd,
    List<String> instruments = const [],
    void Function(double fraction)? onProgress,
  }) =>
      throw UnsupportedError('Upload is not available here');

  Future<String> submitUrl({
    required String url,
    required AudioContentType audioType,
    List<String> instruments = const [],
  }) =>
      throw UnsupportedError('Upload is not available here');

  Future<String> submitReprocess({
    required String sourceJobId,
    required String label,
    required AudioContentType audioType,
    List<String> instruments = const [],
  }) =>
      throw UnsupportedError('Upload is not available here');

  Future<QueueStatus?> status(String requestId) async => null;
}
