import 'job_status.dart';

/// Job creation response model
class JobCreationResponse {
  final String jobId;
  final JobStatus status;
  final String message;

  const JobCreationResponse({
    required this.jobId,
    required this.status,
    required this.message,
  });

  factory JobCreationResponse.fromJson(Map<String, dynamic> json) {
    return JobCreationResponse(
      jobId: json['job_id'] as String,
      status: JobStatus.fromString(json['status'] as String),
      message: json['message'] as String,
    );
  }
}

/// Job results summary model
class JobResultsSummary {
  final String jobId;
  final JobStatus status;
  final int progress;
  final String inputFilename;
  final double duration;
  final double tempoBpm;
  final List<String> stems;
  final bool framesAvailable;
  final bool chordsAvailable;
  final int numFrames;
  final int numChords;
  final double processingTime;
  final String? sourceType;
  final String? sourceUrl;
  final String? videoTitle;

  const JobResultsSummary({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.inputFilename,
    required this.duration,
    required this.tempoBpm,
    required this.stems,
    required this.framesAvailable,
    required this.chordsAvailable,
    required this.numFrames,
    required this.numChords,
    required this.processingTime,
    this.sourceType,
    this.sourceUrl,
    this.videoTitle,
  });

  /// Display name: video title for URL jobs, input filename for file uploads.
  String get displayName => videoTitle ?? inputFilename;

  /// Whether this job was created from a URL.
  bool get isUrlSource => sourceType == 'url';

  factory JobResultsSummary.fromJson(Map<String, dynamic> json) {
    return JobResultsSummary(
      jobId: json['job_id'] as String,
      status: JobStatus.fromString(json['status'] as String),
      progress: json['progress'] as int,
      inputFilename: json['input_filename'] as String,
      duration: (json['duration'] as num).toDouble(),
      tempoBpm: (json['tempo_bpm'] as num).toDouble(),
      stems: (json['stems'] as List<dynamic>).cast<String>(),
      framesAvailable: json['frames_available'] as bool,
      chordsAvailable: json['chords_available'] as bool,
      numFrames: json['num_frames'] as int,
      numChords: json['num_chords'] as int,
      processingTime: (json['processing_time'] as num).toDouble(),
      sourceType: json['source_type'] as String?,
      sourceUrl: json['source_url'] as String?,
      videoTitle: json['video_title'] as String?,
    );
  }

  /// Check if all data is available
  bool get isComplete => framesAvailable && chordsAvailable;

  /// Get formatted duration
  String get durationFormatted {
    final totalSeconds = duration.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted processing time
  String get processingTimeFormatted {
    final totalSeconds = processingTime.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}

/// Stem information model
class StemInfo {
  final String name;
  final String filename;
  final int sizeBytes;
  final String downloadUrl;

  const StemInfo({
    required this.name,
    required this.filename,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  factory StemInfo.fromJson(Map<String, dynamic> json) {
    return StemInfo(
      name: json['name'] as String,
      filename: json['filename'] as String,
      sizeBytes: json['size_bytes'] as int,
      downloadUrl: json['download_url'] as String,
    );
  }

  /// Get formatted file size
  String get sizeFormatted {
    final kb = sizeBytes / 1024;
    final mb = kb / 1024;
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${kb.toStringAsFixed(1)} KB';
  }
}

/// Stems list response model
class StemsListResponse {
  final String jobId;
  final List<StemInfo> stems;

  const StemsListResponse({
    required this.jobId,
    required this.stems,
  });

  factory StemsListResponse.fromJson(Map<String, dynamic> json) {
    final stemsJson = json['stems'] as List<dynamic>;
    return StemsListResponse(
      jobId: json['job_id'] as String,
      stems: stemsJson
          .map((e) => StemInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Find stem by name
  StemInfo? findStem(String name) {
    try {
      return stems.firstWhere((s) => s.name == name);
    } catch (e) {
      return null;
    }
  }
}

/// Job deletion response model
class JobDeletionResponse {
  final String jobId;
  final String message;
  final bool deleted;

  const JobDeletionResponse({
    required this.jobId,
    required this.message,
    required this.deleted,
  });

  factory JobDeletionResponse.fromJson(Map<String, dynamic> json) {
    return JobDeletionResponse(
      jobId: json['job_id'] as String,
      message: json['message'] as String,
      deleted: json['deleted'] as bool,
    );
  }
}

/// Job list item model
class JobListItem {
  final String id;
  final JobStatus status;
  final String? stage;
  final int progress;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final String inputFilename;
  final int fileSize;
  final double duration;
  final double tempoBpm;
  final int numFrames;
  final int numChords;
  final String? sourceType;
  final String? sourceUrl;
  final String? videoTitle;

  const JobListItem({
    required this.id,
    required this.status,
    this.stage,
    required this.progress,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    required this.inputFilename,
    required this.fileSize,
    required this.duration,
    required this.tempoBpm,
    required this.numFrames,
    required this.numChords,
    this.sourceType,
    this.sourceUrl,
    this.videoTitle,
  });

  /// Display name: video title for URL jobs, input filename for file uploads.
  String get displayName => videoTitle ?? inputFilename;

  /// Whether this job was created from a URL.
  bool get isUrlSource => sourceType == 'url';

  factory JobListItem.fromJson(Map<String, dynamic> json) {
    return JobListItem(
      id: json['id'] as String,
      status: JobStatus.fromString(json['status'] as String),
      stage: json['stage'] as String?,
      progress: json['progress'] as int,
      createdAt: DateTime.parse('${json['created_at'] as String}Z').toLocal(),
      startedAt: json['started_at'] != null
          ? DateTime.parse('${json['started_at'] as String}Z').toLocal()
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse('${json['completed_at'] as String}Z').toLocal()
          : null,
      errorMessage: json['error_message'] as String?,
      inputFilename: json['input_filename'] as String,
      fileSize: json['file_size'] as int,
      duration: (json['duration'] as num).toDouble(),
      tempoBpm: (json['tempo_bpm'] as num).toDouble(),
      numFrames: json['num_frames'] as int,
      numChords: json['num_chords'] as int,
      sourceType: json['source_type'] as String?,
      sourceUrl: json['source_url'] as String?,
      videoTitle: json['video_title'] as String?,
    );
  }

  /// Get formatted duration
  String get durationFormatted {
    final totalSeconds = duration.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted file size
  String get fileSizeFormatted {
    final kb = fileSize / 1024;
    final mb = kb / 1024;
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${kb.toStringAsFixed(1)} KB';
  }

  /// Get formatted created date
  String get createdAtFormatted {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Job cancellation response model
class JobCancelResponse {
  final String jobId;
  final bool cancelled;
  final String message;

  const JobCancelResponse({
    required this.jobId,
    required this.cancelled,
    required this.message,
  });

  factory JobCancelResponse.fromJson(Map<String, dynamic> json) {
    return JobCancelResponse(
      jobId: json['job_id'] as String,
      cancelled: json['cancelled'] as bool,
      message: json['message'] as String,
    );
  }
}

/// URL metadata response model
class UrlMetadata {
  final String title;
  final double duration;
  final String? uploader;
  final String? thumbnail;
  final String url;
  final int maxDurationSeconds;

  const UrlMetadata({
    required this.title,
    required this.duration,
    this.uploader,
    this.thumbnail,
    required this.url,
    required this.maxDurationSeconds,
  });

  factory UrlMetadata.fromJson(Map<String, dynamic> json) {
    return UrlMetadata(
      title: json['title'] as String,
      duration: (json['duration'] as num).toDouble(),
      uploader: json['uploader'] as String?,
      thumbnail: json['thumbnail'] as String?,
      url: json['url'] as String,
      maxDurationSeconds: json['max_duration_seconds'] as int? ?? 600,
    );
  }

  String get durationFormatted {
    final totalSeconds = duration.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Job list response model
class JobListResponse {
  final List<JobListItem> jobs;

  const JobListResponse({
    required this.jobs,
  });

  factory JobListResponse.fromJson(Map<String, dynamic> json) {
    final jobsJson = json['jobs'] as List<dynamic>;
    return JobListResponse(
      jobs: jobsJson
          .map((e) => JobListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

