import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Result from [pickFileWeb].
class WebFilePickerResult {
  final Uint8List bytes;
  final String name;
  WebFilePickerResult(this.bytes, this.name);
}

/// Opens a native file-picker dialog in the browser and returns the selected
/// file's bytes and name, or null if the user cancelled.
///
/// [accept] is the HTML accept attribute string (e.g. "audio/*,video/*").
Future<WebFilePickerResult?> pickFileWeb({String accept = '*/*'}) {
  final completer = Completer<WebFilePickerResult?>();

  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = accept
    ..style.display = 'none';

  web.document.body!.append(input);

  input.addEventListener(
    'change',
    (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        input.remove();
        completer.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();
      reader.addEventListener(
        'load',
        (web.Event _) {
          final result = reader.result;
          if (result == null) {
            completer.complete(null);
          } else {
            // result is a JSArrayBuffer
            final jsBuffer = result as JSArrayBuffer;
            final bytes = jsBuffer.toDart.asUint8List();
            completer.complete(WebFilePickerResult(bytes, file.name));
          }
          input.remove();
        }.toJS,
      );
      reader.addEventListener(
        'error',
        (web.Event _) {
          input.remove();
          completer.complete(null);
        }.toJS,
      );
      reader.readAsArrayBuffer(file);
    }.toJS,
  );

  // If the user closes the dialog without picking, fire a cancel after a
  // short focus-return window (the window regains focus after the dialog
  // closes). We listen for the next window-focus or document-click event,
  // whichever comes first, and resolve null if no change fired yet.
  void onFocusBack(web.Event _) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!completer.isCompleted) {
        input.remove();
        completer.complete(null);
      }
    });
  }

  web.window.addEventListener('focus', onFocusBack.toJS);

  input.click();

  return completer.future.then((result) {
    // Listener is single-use; attempt removal (safe even if already gone).
    try {
      web.window.removeEventListener('focus', onFocusBack.toJS);
    } catch (_) {}
    return result;
  });
}
