import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../models/job_status.dart';
import '../../services/transcription_api_service.dart';

/// Songs this computer is processing right now, whoever asked for them (this
/// window, the phone or the website), with their stage and progress. It only
/// watches: finishing a song here never opens it, and nothing is shown when the
/// computer is idle.
class ActiveJobsBanner extends StatefulWidget {
  final TranscriptionApiService apiService;
  const ActiveJobsBanner({super.key, required this.apiService});

  @override
  State<ActiveJobsBanner> createState() => _ActiveJobsBannerState();
}

class _ActiveJobsBannerState extends State<ActiveJobsBanner> {
  static const _every = Duration(seconds: 5);
  Timer? _timer;
  List<JobListItem> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(_every, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final answers = await Future.wait([
      widget.apiService.listJobs(status: 'processing'),
      widget.apiService.listJobs(status: 'queued'),
    ]);
    if (!mounted) return;
    final jobs = [
      for (final answer in answers)
        if (answer.isSuccess && answer.data != null) ...answer.data!.jobs,
    ];
    setState(() => _jobs = jobs);
  }

  @override
  Widget build(BuildContext context) {
    if (_jobs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Working on this Mac', style: theme.textTheme.titleSmall),
            for (final job in _jobs) ...[
              const SizedBox(height: 12),
              Text(job.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: job.progress > 0 ? job.progress / 100 : null),
              const SizedBox(height: 4),
              Text(describeActiveJob(job), style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Separating vocals · 42%", or "Waiting to start" before it begins.
String describeActiveJob(JobListItem job) {
  if (job.status != JobStatus.processing) return 'Waiting to start';
  final stage = job.stage;
  final name = stage == null || stage.isEmpty
      ? 'Starting'
      : '${stage[0].toUpperCase()}${stage.substring(1).replaceAll('_', ' ')}';
  return '$name · ${job.progress}%';
}
