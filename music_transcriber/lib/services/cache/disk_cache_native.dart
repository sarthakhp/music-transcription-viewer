import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A folder of files keyed by an arbitrary string (a URL, say), kept under a
/// size cap by deleting the least recently used files first. Reads touch the
/// file's timestamp so what you open often stays.
class DiskCache {
  const DiskCache(this.name, {this.maxBytes = 400 * 1024 * 1024});

  /// Folder name inside the app's cache directory.
  final String name;
  final int maxBytes;

  Future<Directory> _dir() async {
    final base = await getApplicationCacheDirectory();
    return Directory('${base.path}/$name').create(recursive: true);
  }

  Future<File> _file(String key) async {
    final id = sha1.convert(key.codeUnits).toString();
    return File('${(await _dir()).path}/$id');
  }

  Future<Uint8List?> read(String key) async {
    try {
      final file = await _file(key);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      await file.setLastModified(DateTime.now());
      return bytes;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> write(String key, Uint8List bytes) async {
    try {
      final file = await _file(key);
      // Write then rename, so a crash mid-write never leaves a half file.
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
      await _evictIfNeeded();
    } on FileSystemException catch (e) {
      debugPrint('DiskCache($name) write failed: $e');
    }
  }

  Future<void> _evictIfNeeded() async {
    final files = [
      for (final entity in (await _dir()).listSync())
        if (entity is File && !entity.path.endsWith('.part')) entity,
    ];
    var total = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    if (total <= maxBytes) return;
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    for (final file in files) {
      if (total <= maxBytes) break;
      total -= file.lengthSync();
      await file.delete();
    }
  }
}
