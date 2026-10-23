import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/services/cloud_upload/submission_tracker.dart';
import 'package:music_transcriber/services/cloud_upload/queue_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

String stored(String id, String status, {String? jobId, String? error, DateTime? finishedAt}) => jsonEncode({
      'id': id,
      'label': 'song $id',
      'status': status,
      'job_id': jobId,
      'error': error,
      'finished_at': finishedAt?.millisecondsSinceEpoch,
    });

QueueStatus answer(String id, String status, {String? jobId}) =>
    QueueStatus(id: id, fileName: 'from worker', status: status, jobId: jobId);

void main() {
  final now = DateTime(2026, 10, 23, 14, 0);
  late int finishedCalls;

  /// A tracker whose status lookups never answer unless [fetch] says so.
  SubmissionTracker make({
    Future<QueueStatus?> Function(String id)? fetch,
    DateTime Function()? clock,
  }) {
    finishedCalls = 0;
    return SubmissionTracker(
      fetch ?? (id) => Completer<QueueStatus?>().future,
      onJobFinished: () => finishedCalls++,
      now: clock ?? () => now,
    );
  }

  Future<void> seed(List<String> entries) async {
    SharedPreferences.setMockInitialValues({'submissions_v2': entries});
  }

  test('a finished song is shown as finished the moment the app opens', () async {
    await seed([stored('a', 'done', jobId: 'job-a', finishedAt: now.subtract(const Duration(hours: 2)))]);
    final tracker = make();
    await tracker.restore(); // network never answers

    expect(tracker.items.single.isDone, isTrue);
    expect(tracker.items.single.jobId, 'job-a');
    tracker.dispose();
  });

  test('an unfinished request says "checking", never "waiting", until the worker answers', () async {
    await seed([stored('a', 'checking')]);
    final tracker = make();
    await tracker.restore();

    expect(tracker.items.single.isChecking, isTrue);
    expect(tracker.items.single.status, isNot('queued'));
    tracker.dispose();
  });

  test('only the newest finished song is listed; failures and active ones always are', () async {
    final hourAgo = now.subtract(const Duration(hours: 1));
    await seed([
      stored('active', 'checking'),
      stored('new-done', 'done', jobId: 'j2', finishedAt: hourAgo),
      stored('failed', 'failed', error: 'boom', finishedAt: hourAgo),
      stored('old-done', 'done', jobId: 'j1', finishedAt: hourAgo.subtract(const Duration(hours: 3))),
    ]);
    final tracker = make();
    await tracker.restore();

    expect(tracker.items.map((s) => s.id), ['active', 'new-done', 'failed']);
    tracker.dispose();
  });

  test('a finished song disappears from the list after a day', () async {
    await seed([stored('a', 'done', jobId: 'j', finishedAt: now.subtract(const Duration(hours: 25)))]);
    final tracker = make();
    await tracker.restore();

    expect(tracker.items, isEmpty);
    tracker.dispose();
  });

  test('when a song finishes it is reported once, and its result survives a restart', () async {
    await seed([stored('a', 'checking')]);
    final tracker = make(fetch: (id) async => answer(id, 'done', jobId: 'job-a'));
    await tracker.restore();
    await Future<void>.delayed(Duration.zero);

    expect(tracker.items.single.isDone, isTrue);
    expect(tracker.items.single.fileName, 'song a', reason: 'keeps the label we showed, not the worker\'s');
    expect(finishedCalls, 1);
    tracker.dispose();

    final reopened = make(); // new launch, offline
    await reopened.restore();
    expect(reopened.items.single.isDone, isTrue);
    expect(reopened.items.single.jobId, 'job-a');
    reopened.dispose();
  });

  test('dismissing removes a submission for good', () async {
    await seed([stored('a', 'failed', error: 'boom', finishedAt: now)]);
    final tracker = make();
    await tracker.restore();
    await tracker.dismiss('a');
    expect(tracker.items, isEmpty);
    tracker.dispose();

    final reopened = make();
    await reopened.restore();
    expect(reopened.items, isEmpty);
    reopened.dispose();
  });

  test('requests remembered by the older version show as checking', () async {
    SharedPreferences.setMockInitialValues({
      'phone_submissions': ['old1\tsome song'],
    });
    final tracker = make();
    await tracker.restore();

    expect(tracker.items.single.id, 'old1');
    expect(tracker.items.single.isChecking, isTrue);
    expect((await SharedPreferences.getInstance()).containsKey('phone_submissions'), isFalse);
    tracker.dispose();
  });

  test('a new submission starts as queued and is tracked', () async {
    SharedPreferences.setMockInitialValues({});
    final tracker = make();
    await tracker.restore();
    await tracker.add('n1', 'my song');

    expect(tracker.items.single.status, 'queued');
    expect(tracker.items.single.fileName, 'my song');
    tracker.dispose();
  });
}
