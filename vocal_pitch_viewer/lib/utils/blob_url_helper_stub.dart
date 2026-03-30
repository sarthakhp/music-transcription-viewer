import 'dart:typed_data';

String createBlobUrl(Uint8List bytes, String mimeType) {
  throw UnsupportedError('Blob URLs are only supported on web');
}

void revokeBlobUrl(String url) {
  throw UnsupportedError('Blob URLs are only supported on web');
}
