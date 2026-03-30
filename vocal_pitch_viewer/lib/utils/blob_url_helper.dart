import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Creates a Blob URL for the given bytes. Must be revoked when no longer needed.
String createBlobUrl(Uint8List bytes, String mimeType) {
  final blob = web.Blob(
    [bytes.buffer.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  return web.URL.createObjectURL(blob);
}

/// Revokes a previously created Blob URL, freeing browser memory.
void revokeBlobUrl(String url) {
  web.URL.revokeObjectURL(url);
}
