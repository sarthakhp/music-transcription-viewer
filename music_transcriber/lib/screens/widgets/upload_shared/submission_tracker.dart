import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/cloud_upload/queue_status.dart';

/// The songs this device has submitted, remembered across launches.
///
/// What is remembered includes the *result*, so a finished song shows as
/// finished the moment the app opens, with no false "waiting" while the network
/// catches up. Only unfinished requests are checked again, and until the first
/// answer arrives they show a neutral "checking".
///
/// What is shown ([items]): everything still in progress, failures until
/// dismissed, and only the newest finished song (for a day, or until dismissed).
/// Older finished songs live in the song list, so they are not repeated here.
class SubmissionTracker extends ChangeNotifier {
  static const _prefsKey = 'submissions_v2';
  static const _legacyKey = 'phone_submissions'; // "<id>\t<label>", no result
  static const _maxRemembered = 8;
  static const _pollEvery = Duration(seconds: 6);
  static const doneVisibleFor = Duration(hours: 24);

  final Future<QueueStatus?> Function(String requestId) _fetchStatus;
  final VoidCallback onJobFinished;
  final DateTime Function() _now;

  SubmissionTracker(
    this._fetchStatus, {
    required this.onJobFinished,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final List<_Remembered> _entries = []; // newest first
  Timer? _poll;
  bool _disposed = false;

  /// What the list should show, in order.
  List<QueueStatus> get items {
    final newestDone = _entries.where((e) => e.status.isDone && _stillFresh(e)).firstOrNull;
    return [
      for (final entry in _entries)
        if (!entry.status.isDone || identical(entry, newestDone)) entry.status,
    ];
  }

  bool _stillFresh(_Remembered entry) {
    final finished = entry.finishedAt;
    return finished == null || _now().difference(finished) < doneVisibleFor;
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    for (final raw in prefs.getStringList(_prefsKey) ?? const <String>[]) {
      try {
        _entries.add(_Remembered.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // A damaged entry is dropped rather than breaking the list.
      }
    }
    for (final raw in prefs.getStringList(_legacyKey) ?? const <String>[]) {
      final parts = raw.split('\t');
      if (_entries.any((e) => e.status.id == parts[0])) continue;
      _entries.add(_Remembered(QueueStatus.checking(id: parts[0], fileName: parts.length > 1 ? parts[1] : '')));
    }
    if (prefs.containsKey(_legacyKey)) await prefs.remove(_legacyKey);
    _prune();
    notifyListeners();
    refresh();
  }

  Future<void> add(String id, String label) async {
    _entries.insert(0, _Remembered(QueueStatus(id: id, fileName: label, status: 'queued')));
    _prune();
    notifyListeners();
    await _save();
    refresh();
  }

  /// Removes a submission from the list (a finished song stays in the song list).
  Future<void> dismiss(String id) async {
    _entries.removeWhere((e) => e.status.id == id);
    notifyListeners();
    await _save();
  }

  /// Fetches fresh state for every unfinished submission, then schedules the
  /// next check while any remain.
  Future<void> refresh() async {
    _poll?.cancel();
    var finishedNow = false;
    for (final entry in List.of(_entries)) {
      if (!entry.status.isActive) continue;
      final fresh = await _fetchStatus(entry.status.id);
      if (fresh == null || _disposed) continue;
      entry.status = fresh.withLabel(entry.status.fileName);
      if (!entry.status.isActive) {
        entry.finishedAt ??= _now();
        finishedNow = finishedNow || entry.status.isDone;
        await _save();
      }
      notifyListeners();
    }
    if (finishedNow) onJobFinished();
    if (!_disposed && _entries.any((e) => e.status.isActive)) {
      _poll = Timer(_pollEvery, refresh);
    }
  }

  /// Forget finished songs that are no longer shown, and cap what is kept.
  void _prune() {
    final keep = items.map((s) => s.id).toSet();
    _entries.removeWhere((e) => e.status.isDone && !keep.contains(e.status.id));
    while (_entries.length > _maxRemembered) {
      _entries.removeLast();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, [for (final e in _entries) jsonEncode(e.toJson())]);
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}

/// A submission plus when we first saw it finish.
class _Remembered {
  QueueStatus status;
  DateTime? finishedAt;

  _Remembered(this.status, {this.finishedAt});

  factory _Remembered.fromJson(Map<String, dynamic> json) {
    final finishedMs = json['finished_at'] as int?;
    return _Remembered(
      QueueStatus(
        id: json['id'] as String,
        fileName: (json['label'] as String?) ?? '',
        status: json['status'] as String,
        jobId: json['job_id'] as String?,
        error: json['error'] as String?,
      ),
      finishedAt: finishedMs == null ? null : DateTime.fromMillisecondsSinceEpoch(finishedMs),
    );
  }

  /// Only the final state is saved. An unfinished request is stored as such and
  /// shows "checking" on the next launch until the worker's state arrives.
  Map<String, dynamic> toJson() => {
        'id': status.id,
        'label': status.fileName,
        'status': status.isActive ? 'checking' : status.status,
        'job_id': status.jobId,
        'error': status.error,
        'finished_at': finishedAt?.millisecondsSinceEpoch,
      };
}
