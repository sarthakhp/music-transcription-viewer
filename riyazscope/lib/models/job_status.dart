/// Job status enumeration
enum JobStatus {
  queued,
  processing,
  completed,
  failed,
  cancelled;

  /// Parse status from string
  static JobStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'queued':
        return JobStatus.queued;
      case 'processing':
        return JobStatus.processing;
      case 'completed':
        return JobStatus.completed;
      case 'failed':
        return JobStatus.failed;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        throw ArgumentError('Unknown job status: $status');
    }
  }

  /// Convert to string
  String toApiString() {
    return name;
  }

  /// Check if job is in a terminal state
  bool get isTerminal =>
      this == JobStatus.completed ||
      this == JobStatus.failed ||
      this == JobStatus.cancelled;

  /// Check if job is still processing
  bool get isActive => this == JobStatus.queued || this == JobStatus.processing;
}

/// Processing stage enumeration
enum ProcessingStage {
  download,
  separation,
  transcription,
  instruments,
  chords;

  /// Parse stage from string
  static ProcessingStage fromString(String stage) {
    switch (stage.toLowerCase()) {
      case 'download':
        return ProcessingStage.download;
      case 'separation':
        return ProcessingStage.separation;
      case 'transcription':
        return ProcessingStage.transcription;
      case 'instruments':
        return ProcessingStage.instruments;
      case 'chords':
        return ProcessingStage.chords;
      default:
        throw ArgumentError('Unknown processing stage: $stage');
    }
  }

  /// Get display name for the stage
  String get displayName {
    switch (this) {
      case ProcessingStage.download:
        return 'Downloading';
      case ProcessingStage.separation:
        return 'Source Separation';
      case ProcessingStage.transcription:
        return 'Vocal Transcription';
      case ProcessingStage.instruments:
        return 'Instrument Transcription';
      case ProcessingStage.chords:
        return 'Chord Detection';
    }
  }

  /// Get progress range for this stage (0-100)
  (int start, int end) get progressRange {
    switch (this) {
      case ProcessingStage.download:
        return (0, 15);
      case ProcessingStage.separation:
        return (15, 45);
      case ProcessingStage.transcription:
        return (45, 65);
      case ProcessingStage.instruments:
        return (65, 80);
      case ProcessingStage.chords:
        return (80, 100);
    }
  }
}

/// Job status response model
class JobStatusResponse {
  final String id;
  final JobStatus status;
  final ProcessingStage? stage;
  final int progress;
  final String? errorMessage;
  final String? message;

  const JobStatusResponse({
    required this.id,
    required this.status,
    this.stage,
    required this.progress,
    this.errorMessage,
    this.message,
  });

  factory JobStatusResponse.fromJson(Map<String, dynamic> json) {
    try {
      return JobStatusResponse(
        id: json['id'] as String? ?? '',
        status: JobStatus.fromString(json['status'] as String? ?? 'queued'),
        stage: json['stage'] != null
            ? ProcessingStage.fromString(json['stage'] as String)
            : null,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        errorMessage: json['error_message'] as String?,
        message: json['message'] as String?,
      );
    } catch (e) {
      throw FormatException('Failed to parse JobStatusResponse: $e, JSON: $json');
    }
  }

  /// Get current stage display name
  String get currentStageDisplay {
    if (stage != null) {
      return stage!.displayName;
    }
    return status == JobStatus.queued ? 'Queued' : 'Processing';
  }

  /// Check if job is complete
  bool get isComplete => status == JobStatus.completed;

  /// Check if job has failed
  bool get hasFailed => status == JobStatus.failed;

  /// Check if job was cancelled
  bool get isCancelled => status == JobStatus.cancelled;

  /// Check if job is still processing
  bool get isProcessing => status.isActive;
}

