import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'blob_url_helper.dart';

/// Triggers a browser "Save As" download of [bytes] as [filename].
void downloadBytes(Uint8List bytes, String filename, String mimeType) {
  final url = createBlobUrl(bytes, mimeType);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  revokeBlobUrl(url);
}
