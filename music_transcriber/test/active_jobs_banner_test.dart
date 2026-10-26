import 'package:flutter_test/flutter_test.dart';
import 'package:music_transcriber/models/job.dart';
import 'package:music_transcriber/models/job_status.dart';
import 'package:music_transcriber/screens/widgets/active_jobs_banner.dart';

JobListItem _job(JobStatus status, {String? stage, int progress = 0}) => JobListItem(
      id: 'j', status: status, stage: stage, progress: progress,
      createdAt: DateTime(2026, 10, 20), inputFilename: 'a.mp3', fileSize: 0,
      duration: 0, tempoBpm: 0, numFrames: 0, numChords: 0,
    );

void main() {
  test('a job that has not started says so', () {
    expect(describeActiveJob(_job(JobStatus.queued)), 'Waiting to start');
  });

  test('a running job shows its stage and percent', () {
    expect(describeActiveJob(_job(JobStatus.processing, stage: 'separation', progress: 42)), 'Separation · 42%');
    expect(describeActiveJob(_job(JobStatus.processing, stage: 'vocal_pitch', progress: 7)), 'Vocal pitch · 7%');
    expect(describeActiveJob(_job(JobStatus.processing, progress: 1)), 'Starting · 1%');
  });
}
