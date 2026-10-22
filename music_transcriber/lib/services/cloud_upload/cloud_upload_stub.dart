import 'dart:typed_data';
import '../../models/audio_content_type.dart';
import 'queue_status.dart';

/// Web has no phone-upload path (the hosted viewer stays read-only).
class CloudUpload {
  static const bool isSupported = false;

  Future<String?> signedInEmail() async => null;
  Future<String> signIn() => throw UnsupportedError('Upload is Android only');
  Future<void> signOut() async {}
  Future<String> submit({
    required Uint8List bytes,
    required String fileName,
    required AudioContentType audioType,
    void Function(double fraction)? onProgress,
  }) =>
      throw UnsupportedError('Upload is Android only');
  Future<QueueStatus?> status(String requestId) async => null;
}
