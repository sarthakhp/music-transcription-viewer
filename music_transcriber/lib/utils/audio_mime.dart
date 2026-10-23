/// Content type for an audio/video file name, for uploads where the browser
/// gives only bytes. Unknown types fall back to a generic binary type, which
/// the storage rules accept.
String audioMimeTypeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'flac' => 'audio/flac',
    'm4a' => 'audio/mp4',
    'aac' => 'audio/aac',
    'ogg' || 'opus' => 'audio/ogg',
    'webm' => 'audio/webm',
    'mp4' => 'video/mp4',
    _ => 'application/octet-stream',
  };
}

/// File extension a recording of this MIME type should get.
String extensionForMime(String mimeType) {
  final base = mimeType.split(';').first.trim();
  return switch (base) {
    'audio/webm' => 'webm',
    'audio/ogg' => 'ogg',
    'audio/mp4' => 'm4a',
    'audio/wav' || 'audio/x-wav' => 'wav',
    _ => 'webm',
  };
}
