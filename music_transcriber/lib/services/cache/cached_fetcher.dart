import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'disk_cache.dart';

/// Downloads URLs with a disk cache in front.
///
/// [getImmutable] is for files whose URL changes whenever their content does
/// (published files carry a new token when reprocessed): once cached, they are
/// never fetched again. [getRevalidated] is for files that can change in place
/// (the song list): it hands back the saved copy at once and fetches a fresh one.
class CachedFetcher {
  final http.Client _client;
  final DiskCache _cache;
  final Duration timeout;

  CachedFetcher(this._client, this._cache, {required this.timeout});

  Future<Uint8List> getImmutable(String url) async {
    final saved = await _cache.read(url);
    if (saved != null) return saved;
    final bytes = await _download(url);
    await _cache.write(url, bytes);
    return bytes;
  }

  /// Fetches fresh bytes (and saves them). Falls back to the saved copy when
  /// offline, and throws only if neither exists.
  Future<Uint8List> getFresh(String url) async {
    try {
      final bytes = await _download(url);
      await _cache.write(url, bytes);
      return bytes;
    } catch (_) {
      final saved = await _cache.read(url);
      if (saved != null) return saved;
      rethrow;
    }
  }

  Future<Uint8List?> peek(String url) => _cache.read(url);

  /// One automatic second try: a dropped connection on a big file is common on
  /// phones and slow networks, and a plain retry usually succeeds.
  Future<Uint8List> _download(String url) async {
    try {
      return await _downloadOnce(url);
    } catch (_) {
      return _downloadOnce(url);
    }
  }

  Future<Uint8List> _downloadOnce(String url) async {
    final res = await _client.get(Uri.parse(url)).timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return res.bodyBytes;
  }
}
