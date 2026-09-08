/// API configuration for the Music Transcription service
class ApiConfig {
  // Data source mode, set at build time:
  //   flutter build web --dart-define=DATA_SOURCE=remote \
  //       --dart-define=FIREBASE_INDEX_URL=<public index.json URL>
  // 'local'  → talk to the processing backend (full create + process + view).
  // 'remote' → read-only hosted viewer that reads published artifacts from
  //            Firebase Storage public URLs; no backend required.
  static const String dataSource =
      String.fromEnvironment('DATA_SOURCE', defaultValue: 'local');
  static bool get isRemote => dataSource == 'remote';

  /// Public download URL of index.json in Firebase Storage (remote mode only).
  static const String firebaseIndexUrl =
      String.fromEnvironment('FIREBASE_INDEX_URL');

  // Base URL for the API.
  // When running as a bundled desktop app the Flutter web UI is served by the
  // same FastAPI server, so we use the current page's origin — this way the
  // port is always correct regardless of which port the launcher chose.
  // In development (flutter run / firebase hosting) fall back to localhost:8000.
  static const bool _useNgrok = false;
  static const String _ngrokUrl = 'https://hypocotylous-krysten-abominably.ngrok-free.dev';
  static String get _localhostUrl {
    // ignore: undefined_prefixed_name
    try {
      // On the web, Uri.base gives the page's origin (scheme+host+port).
      // This works both in the bundled desktop app and in a browser.
      final uri = Uri.base;
      if (uri.host.isNotEmpty) {
        return '${uri.scheme}://${uri.host}:${uri.port}';
      }
    } catch (_) {}
    return 'http://localhost:8000';
  }
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

