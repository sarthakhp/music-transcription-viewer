import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import 'cached_fetcher.dart';

/// The published song list (index.json), served saved-copy-first.
///
/// [load] answers from memory or the copy saved on this device, so the list
/// appears instantly, and checks for a newer one in the background. When the
/// background check finds a change it emits on [updates] so the screen can
/// redraw. With nothing saved yet (first launch) it waits for the network.
class RemoteIndexStore {
  RemoteIndexStore(this._fetcher);

  final CachedFetcher _fetcher;
  final _updates = StreamController<void>.broadcast();

  Map<String, dynamic>? _index;
  Uint8List? _raw;

  Stream<void> get updates => _updates.stream;

  /// The loaded index, if any, without touching disk or network.
  Map<String, dynamic>? get current => _index;

  String get _url {
    final url = ApiConfig.firebaseIndexUrl;
    if (url.isEmpty) {
      throw StateError(
        'FIREBASE_INDEX_URL is not set. Build with '
        '--dart-define=FIREBASE_INDEX_URL=<public index.json URL>.',
      );
    }
    return url;
  }

  Future<Map<String, dynamic>> load() async {
    final loaded = _index;
    if (loaded != null) return loaded;
    final saved = await _fetcher.peek(_url);
    if (saved != null) {
      _adopt(saved);
      unawaited(refresh().catchError((_) => <String, dynamic>{}));
      return _index!;
    }
    return _adopt(await _fetcher.getFresh(_url));
  }

  /// Fetches the latest index now and notifies listeners if it changed.
  Future<Map<String, dynamic>> refresh() async {
    final bytes = await _fetcher.getFresh(_url);
    if (_raw != null && listEquals(bytes, _raw)) return _index!;
    final index = _adopt(bytes);
    _updates.add(null);
    return index;
  }

  Map<String, dynamic> _adopt(Uint8List bytes) {
    _raw = bytes;
    return _index = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  void dispose() => _updates.close();
}
