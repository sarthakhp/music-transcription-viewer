import 'dart:typed_data';

/// Web has the browser's own HTTP cache, so this does nothing there.
class DiskCache {
  const DiskCache(this.name, {this.maxBytes = 0});
  final String name;
  final int maxBytes;

  Future<Uint8List?> read(String key) async => null;
  Future<void> write(String key, Uint8List bytes) async {}
}
