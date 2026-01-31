/// API configuration for the Music Transcription service
class ApiConfig {
  // Base URL for the API - Switch between ngrok and localhost here
  static const bool _useNgrok = true; // Change to false for localhost
  static const String _ngrokUrl = 'https://hypocotylous-krysten-abominably.ngrok-free.dev';
  static const String _localhostUrl = 'http://localhost:8000';
  static String get baseUrl => _useNgrok ? _ngrokUrl : _localhostUrl;
  
  // API version
  static const String apiVersion = 'v1';
  
  // Full base path
  static String get basePath => '$baseUrl/api/$apiVersion';
  
  // Endpoints
  static const String transcribeEndpoint = '/transcribe';
  static const String jobsEndpoint = '/jobs';
  static const String healthEndpoint = '/health';
  
  // Timeouts
  static const Duration uploadTimeout = Duration(minutes: 5);
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration downloadTimeout = Duration(minutes: 10);
  
  // Polling configuration
  static const Duration pollingInterval = Duration(seconds: 3);
  static const int maxPollingAttempts = 600; // 30 minutes max (600 * 3s)
  
  // File upload constraints
  static const int maxFileSizeBytes = 100 * 1024 * 1024; // 100MB
  static const List<String> supportedFormats = ['mp3', 'wav', 'flac', 'm4a', 'ogg', 'webm'];
  
  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  /// Get full URL for an endpoint
  static String getUrl(String endpoint) {
    if (endpoint.startsWith('/')) {
      return '$basePath$endpoint';
    }
    return '$basePath/$endpoint';
  }
  
  /// Get health check URL
  static String get healthUrl => '$baseUrl$healthEndpoint';
  
  /// Check if file format is supported
  static bool isSupportedFormat(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    return supportedFormats.contains(extension);
  }
  
  /// Check if file size is within limits
  static bool isValidFileSize(int sizeBytes) {
    return sizeBytes <= maxFileSizeBytes;
  }
  
  /// Get human-readable file size limit
  static String get maxFileSizeFormatted => '${maxFileSizeBytes ~/ (1024 * 1024)}MB';
}

