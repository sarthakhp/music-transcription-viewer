/// One phone submission as the processing worker reports it in
/// `queue/<id>.json`: queued → claimed → processing → done | failed.
class QueueStatus {
  final String id;
  final String fileName;
  final String status;
  final int progress;
  final String? stage;
  final String? jobId;
  final String? error;

  const QueueStatus({
    required this.id,
    required this.fileName,
    required this.status,
    this.progress = 0,
    this.stage,
    this.jobId,
    this.error,
  });

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isActive => !isDone && !isFailed;

  factory QueueStatus.fromJson(Map<String, dynamic> json) => QueueStatus(
        id: json['id'] as String,
        fileName: (json['filename'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'queued',
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        stage: json['stage'] as String?,
        jobId: json['job_id'] as String?,
        error: json['error'] as String?,
      );
}
