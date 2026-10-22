import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Result from [pickFileWeb] (name kept so callers are platform-agnostic).
class WebFilePickerResult {
  final Uint8List bytes;
  final String name;
  WebFilePickerResult(this.bytes, this.name);
}

const _audioExtensions = ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg', 'opus', 'webm', 'mp4'];

/// Opens the Android system file picker and returns the file's bytes and name,
/// or null if the user cancelled. [accept] is ignored; [hint] picks the filter.
Future<WebFilePickerResult?> pickFileWeb({
  String accept = '*/*',
  String hint = 'audio',
}) async {
  final file = await FilePicker.pickFile(
    type: hint == '*' ? FileType.any : FileType.custom,
    allowedExtensions: hint == 'json'
        ? const ['json']
        : hint == '*'
            ? null
            : _audioExtensions,
  );
  final path = file?.path;
  if (file == null || path == null) return null;
  return WebFilePickerResult(await File(path).readAsBytes(), file.name);
}
