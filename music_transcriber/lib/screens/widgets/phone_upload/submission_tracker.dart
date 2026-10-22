import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/cloud_upload/cloud_upload.dart';

/// The songs this phone has submitted, remembered across launches and kept
/// current by polling the worker's status. Calls [onJobFinished] whenever one
/// finishes so the library can refresh.
class SubmissionTracker extends ChangeNotifier {
  static const _prefsKey = 'phone_submissions'; // "<id>\t<label>"
  static const _maxRemembered = 8;
  static const _pollEvery = Duration(seconds: 6);

  final CloudUpload _cloud;
  final VoidCallback onJobFinished;

  SubmissionTracker(this._cloud, {required this.onJobFinished});

  final List<QueueStatus> _items = [];
  Timer? _poll;
  bool _disposed = false;

  List<QueueStatus> get items => List.unmodifiable(_items);

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in prefs.getStringList(_prefsKey) ?? const <String>[]) {
      final parts = entry.split('\t');
      _items.add(QueueStatus(
        id: parts[0],
        fileName: parts.length > 1 ? parts[1] : '',
        status: 'queued',
      ));
    }
    notifyListeners();
    refresh();
  }

  Future<void> add(String id, String label) async {
    _items.insert(0, QueueStatus(id: id, fileName: label, status: 'queued'));
    if (_items.length > _maxRemembered) _items.removeLast();
    notifyListeners();
    await _save();
    refresh();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      [for (final s in _items) '${s.id}\t${s.fileName}'],
    );
  }

  /// Fetches fresh status for every unfinished submission, then schedules the
  /// next check while any remain.
  Future<void> refresh() async {
    _poll?.cancel();
    var finishedNow = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isActive) continue;
      final fresh = await _cloud.status(_items[i].id);
      if (fresh == null || _disposed) continue;
      if (fresh.isDone) finishedNow = true;
      _items[i] = fresh;
      notifyListeners();
    }
    if (finishedNow) onJobFinished();
    if (!_disposed && _items.any((s) => s.isActive)) {
      _poll = Timer(_pollEvery, refresh);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
