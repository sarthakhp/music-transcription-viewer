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

// ── pywebview bridge ──────────────────────────────────────────────────────────
// index.html defines window.__pickFile(hint) which returns:
//   {name, data}           — file picked via pywebview native dialog
//   null                   — user cancelled in pywebview
//   {_unavailable: true}   — not running in pywebview; use HTML input fallback
//
// This sentinel approach avoids relying on @JS bool globals, which dart2js
// release builds don't read reliably from window.* properties.

extension type _PickResult._(JSObject _) implements JSObject {
  external String? get name;
  external String? get data;
  // ignore: non_constant_identifier_names
  external bool? get _unavailable;
}

@JS('__pickFile')
external JSPromise<_PickResult?> _jsPickFile(String hint);

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
/// [accept] is the HTML accept attribute string used in browser mode.
/// [hint] is passed to the pywebview native API: 'audio', 'json', or '*'.
Future<WebFilePickerResult?> pickFileWeb({
  String accept = '*/*',
  String hint = 'audio',
}) async {
  // Always call __pickFile first. It returns {_unavailable:true} when not in
  // pywebview, signalling us to fall back to the HTML input approach.
  final result = await _jsPickFile(hint).toDart;

  if (result == null) {
    // User cancelled in pywebview.
    return null;
  }

  if (result._unavailable == true) {
    // Not in pywebview — use HTML <input type="file">.
    return _pickFileHtmlInput(accept);
  }

  // Got a file from pywebview native dialog.
  final bytes = base64Decode(result.data!);
  return WebFilePickerResult(bytes, result.name!);
}
