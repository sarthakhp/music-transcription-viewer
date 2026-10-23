import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../phone_audio/selected_audio.dart';
import 'shared_item.dart';

/// Receives what other apps share to this one ("Share to Music Transcriber").
///
/// Started once from main(), so a share that launches the app cold is caught
/// wherever the user lands. A share nobody is listening for yet waits in
/// [takePending], and the upload panel picks it up when it appears.
class ShareIntake {
  ShareIntake._();
  static final ShareIntake instance = ShareIntake._();

  static const _channel = MethodChannel('music_transcriber/share');

  final _controller = StreamController<SharedItem>.broadcast();
  SharedItem? _pending;
  String? _lastKey;
  bool _started = false;

  Stream<SharedItem> get items => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') _deliver(call.arguments);
    });
    try {
      _deliver(await _channel.invokeMethod<Object?>('takeInitial'));
    } on MissingPluginException {
      // Not Android (web, desktop): nothing can be shared in.
    }
  }

  /// The share that arrived while no panel was listening, if any.
  SharedItem? takePending() {
    final item = _pending;
    _pending = null;
    return item;
  }

  void _deliver(Object? arguments) {
    debugPrint('ShareDebug dart got: $arguments listener=${_controller.hasListener}');
    final item = _parse(arguments);
    if (item == null) return;
    if (_controller.hasListener) {
      _controller.add(item);
    } else {
      _pending = item;
    }
  }

  SharedItem? _parse(Object? arguments) {
    if (arguments is! Map) return null;
    final key = '${arguments['type']}|${arguments['path'] ?? arguments['url']}';
    // The same share can arrive twice around startup; ignore the repeat.
    if (key == _lastKey) return null;
    _lastKey = key;
    switch (arguments['type']) {
      case 'link':
        return SharedLink(arguments['url'] as String);
      case 'audio':
        return SharedAudio(SelectedAudio(
          path: arguments['path'] as String,
          name: arguments['name'] as String,
        ));
    }
    return null;
  }
}
