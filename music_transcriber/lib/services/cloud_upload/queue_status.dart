/// One submission as the processing worker reports it in `queue/<id>.json`:
/// queued -> claimed -> processing -> done | failed. [checking] is only ever
/// used locally, for a remembered request whose state has not been fetched yet.
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

  /// A request we remember but have not heard about yet. It is not claimed to
  /// be waiting or finished: that is only known once the worker's state arrives.
  const QueueStatus.checking({required this.id, required this.fileName})
      : status = 'checking',
        progress = 0,
        stage = null,
        jobId = null,
        error = null;

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isChecking => status == 'checking';
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

  /// This status with the label we showed for it, which the worker does not know.
  QueueStatus withLabel(String label) => QueueStatus(
        id: id,
        fileName: label,
        status: status,
        progress: progress,
        stage: stage,
        jobId: jobId,
        error: error,
      );
}
