import 'package:file_picker/file_picker.dart';
import 'selected_audio.dart';

const _audioExtensions = ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg', 'opus', 'webm', 'mp4'];

/// Opens the Android file picker for an audio file. The picker hands back a
/// copy in app cache, so the clip owns it and deletes it when dropped.
Future<SelectedAudio?> pickAudioFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: _audioExtensions,
  );
  final path = file?.path;
  if (file == null || path == null) return null;
  return SelectedAudio(path: path, name: file.name);
}
