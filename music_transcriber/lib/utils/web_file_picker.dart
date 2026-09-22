import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Result from [pickFileWeb].
class WebFilePickerResult {
  final Uint8List bytes;
  final String name;
  WebFilePickerResult(this.bytes, this.name);
}

// ── pywebview detection ───────────────────────────────────────────────────────
// index.html injects window.__inPywebview (bool) and window.__pickFile(hint)
// so Dart doesn't need to traverse window.pywebview.api through extension
// types, which fails in compiled Flutter JS because the global isn't resolved
// the same way.

extension type _PickResult._(JSObject _) implements JSObject {
  external String get name;
  external String get data;
}

@JS('__inPywebview')
external bool get _inPywebview;

@JS('__pickFile')
external JSPromise<_PickResult?> _jsPickFile(String hint);

Future<WebFilePickerResult?> _pickFilePywebview(String hint) async {
  final result = await _jsPickFile(hint).toDart;
  if (result == null) return null;
  final bytes = base64Decode(result.data);
  return WebFilePickerResult(bytes, result.name);
}

// ── HTML <input type="file"> fallback (browser / GitHub Pages) ────────────────

Future<WebFilePickerResult?> _pickFileHtmlInput(String accept) {
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
    try {
      web.window.removeEventListener('focus', onFocusBack.toJS);
    } catch (_) {}
    return result;
  });
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Opens a native file-picker dialog and returns the selected file's bytes and
/// name, or null if the user cancelled.
///
/// [accept] is the HTML accept attribute string used in browser mode
/// (e.g. "audio/*,video/*,.mp3").
/// [hint] is passed to the pywebview native API: 'audio', 'json', or '*'.
Future<WebFilePickerResult?> pickFileWeb({
  String accept = '*/*',
  String hint = 'audio',
}) {
  if (_inPywebview) {
    return _pickFilePywebview(hint);
  }
  return _pickFileHtmlInput(accept);
}
