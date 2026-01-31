import 'package:flutter/foundation.dart';
import '../models/pitch_data.dart';
import '../models/chord_data.dart';
import '../models/job_status.dart';

/// Main application state provider
class AppState extends ChangeNotifier {
  // Data state
  ProcessedFramesData? _pitchData;
  ChordData? _chordData;
  Uint8List? _audioBytes;
  String? _audioFileName;

  // Audio stems (NEW - for API data)
  Uint8List? _originalAudio;
  Uint8List? _vocalsAudio;
  Uint8List? _instrumentalAudio;

  // Playback state
  bool _isPlaying = false;
  double _currentTime = 0;
  double _duration = 0;

  // Display state
  double _referenceFrequency = 440.0; // A4 reference frequency in Hz

  // Job state (NEW)
  String? _currentJobId;
  JobStatus? _jobStatus;
  ProcessingStage? _processingStage;
  int _processingProgress = 0;
  bool _isUploading = false;
  bool _isProcessing = false;

  // Error and loading state
  String? _errorMessage;
  bool _isLoading = false;

  // Getters - Data
  ProcessedFramesData? get pitchData => _pitchData;
  ChordData? get chordData => _chordData;
  Uint8List? get audioBytes => _audioBytes;
  String? get audioFileName => _audioFileName;

  // Getters - Audio stems (NEW)
  Uint8List? get originalAudio => _originalAudio;
  Uint8List? get vocalsAudio => _vocalsAudio;
  Uint8List? get instrumentalAudio => _instrumentalAudio;

  // Getters - Playback
  bool get isPlaying => _isPlaying;
  double get currentTime => _currentTime;
  double get duration => _duration;

  // Getters - Display
  double get referenceFrequency => _referenceFrequency;

  // Getters - Job state (NEW)
  String? get currentJobId => _currentJobId;
  JobStatus? get jobStatus => _jobStatus;
  ProcessingStage? get processingStage => _processingStage;
  int get processingProgress => _processingProgress;
  bool get isUploading => _isUploading;
  bool get isProcessing => _isProcessing;

  // Getters - Error and loading
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  // Computed getters
  bool get hasData => _pitchData != null;
  bool get hasAudio => _audioBytes != null;
  bool get hasChords => _chordData != null;
  bool get isReady => hasData && hasAudio;
  bool get hasActiveJob => _currentJobId != null;
  bool get isJobComplete => _jobStatus == JobStatus.completed;
  bool get isJobFailed => _jobStatus == JobStatus.failed;
  bool get isJobProcessing => _jobStatus == JobStatus.processing;
  bool get canUpload => !_isUploading && !_isProcessing;

  // Setters with notification
  void setPitchData(ProcessedFramesData? data) {
    _pitchData = data;
    _errorMessage = null;
    notifyListeners();
  }

  void setAudioData(Uint8List? bytes, String? fileName) {
    _audioBytes = bytes;
    _audioFileName = fileName;
    _errorMessage = null;
    notifyListeners();
  }

  // Setters for audio stems (NEW)
  void setOriginalAudio(Uint8List? audio) {
    _originalAudio = audio;
    notifyListeners();
  }

  void setVocalsAudio(Uint8List? audio) {
    _vocalsAudio = audio;
    notifyListeners();
  }

  void setInstrumentalAudio(Uint8List? audio) {
    _instrumentalAudio = audio;
    notifyListeners();
  }

  void setAllAudioStems({
    Uint8List? original,
    Uint8List? vocals,
    Uint8List? instrumental,
  }) {
    _originalAudio = original;
    _vocalsAudio = vocals;
    _instrumentalAudio = instrumental;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  void setCurrentTime(double time) {
    _currentTime = time;
    notifyListeners();
  }

  void setDuration(double duration) {
    _duration = duration;
    notifyListeners();
  }

  void setChordData(ChordData? data) {
    _chordData = data;
    notifyListeners();
  }

  void setReferenceFrequency(double frequency) {
    _referenceFrequency = frequency.clamp(400.0, 480.0); // Common range: 400-480 Hz
    notifyListeners();
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Job management setters (NEW)

  void setCurrentJobId(String? jobId) {
    _currentJobId = jobId;
    notifyListeners();
  }

  void setJobStatus(JobStatus? status) {
    _jobStatus = status;
    notifyListeners();
  }

  void setProcessingStage(ProcessingStage? stage) {
    _processingStage = stage;
    notifyListeners();
  }

  void setProcessingProgress(int progress) {
    _processingProgress = progress.clamp(0, 100);
    notifyListeners();
  }

  void setUploading(bool uploading) {
    _isUploading = uploading;
    notifyListeners();
  }

  void setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  /// Update job state from JobStatusResponse
  void updateJobState({
    required String jobId,
    required JobStatus status,
    ProcessingStage? stage,
    required int progress,
  }) {
    _currentJobId = jobId;
    _jobStatus = status;
    _processingStage = stage;
    _processingProgress = progress.clamp(0, 100);
    _isProcessing = status == JobStatus.processing || status == JobStatus.queued;
    notifyListeners();
  }

  /// Start upload process
  void startUpload() {
    _isUploading = true;
    _errorMessage = null;
    notifyListeners();
  }

  /// Complete upload and start processing
  void completeUpload(String jobId) {
    _isUploading = false;
    _currentJobId = jobId;
    _jobStatus = JobStatus.queued;
    _isProcessing = true;
    _processingProgress = 0;
    notifyListeners();
  }

  /// Complete job processing
  void completeJob() {
    _isProcessing = false;
    _jobStatus = JobStatus.completed;
    _processingProgress = 100;
    notifyListeners();
  }

  /// Fail job processing
  void failJob(String errorMessage) {
    _isProcessing = false;
    _isUploading = false;
    _jobStatus = JobStatus.failed;
    _errorMessage = errorMessage;
    notifyListeners();
  }

  /// Clear job state
  void clearJobState() {
    _currentJobId = null;
    _jobStatus = null;
    _processingStage = null;
    _processingProgress = 0;
    _isUploading = false;
    _isProcessing = false;
    notifyListeners();
  }

  void reset() {
    _pitchData = null;
    _chordData = null;
    _audioBytes = null;
    _audioFileName = null;
    _isPlaying = false;
    _currentTime = 0;
    _duration = 0;
    _errorMessage = null;
    _isLoading = false;

    // Clear audio stems (NEW)
    _originalAudio = null;
    _vocalsAudio = null;
    _instrumentalAudio = null;

    // Clear job state
    _currentJobId = null;
    _jobStatus = null;
    _processingStage = null;
    _processingProgress = 0;
    _isUploading = false;
    _isProcessing = false;

    notifyListeners();
  }
}

