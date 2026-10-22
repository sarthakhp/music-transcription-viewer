import 'dart:io';

/// An audio file chosen or recorded on this phone. [ownsFile] marks temporary
/// copies (recordings, the picker's cache copy) that must be deleted when the
/// clip is dropped, so nothing piles up in app storage.
class SelectedAudio {
  final String path;
  final String name;
  final bool ownsFile;

  const SelectedAudio({
    required this.path,
    required this.name,
    this.ownsFile = true,
  });

  bool get isWav => path.toLowerCase().endsWith('.wav');

  Future<void> delete() async {
    if (!ownsFile) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}
