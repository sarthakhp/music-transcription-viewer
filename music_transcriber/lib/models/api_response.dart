/// Generic API response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  final bool isSuccess;

  const ApiResponse._({
    this.data,
    this.error,
    this.statusCode,
    required this.isSuccess,
  });

  /// Create a successful response
  factory ApiResponse.success(T data, {int? statusCode}) {
    return ApiResponse._(
      data: data,
      statusCode: statusCode,
      isSuccess: true,
    );
  }

  /// Create an error response
  factory ApiResponse.error(String error, {int? statusCode}) {
    return ApiResponse._(
      error: error,
      statusCode: statusCode,
      isSuccess: false,
    );
  }

  /// Create a network error response
  factory ApiResponse.networkError([String? message]) {
    return ApiResponse._(
      error: message ?? 'Network error. Please check your connection.',
      isSuccess: false,
    );
  }

  /// Create a timeout error response
  factory ApiResponse.timeout([String? message]) {
    return ApiResponse._(
      error: message ?? 'Request timed out. Please try again.',
      isSuccess: false,
    );
  }

  /// Check if response has data
  bool get hasData => data != null;

  /// Check if response has error
  bool get hasError => error != null;

  /// Get data or throw error
  T get dataOrThrow {
    if (isSuccess && data != null) {
      return data!;
    }
    throw Exception(error ?? 'Unknown error');
  }

  /// Map the data to another type
  ApiResponse<R> map<R>(R Function(T data) transform) {
    if (isSuccess && data != null) {
      try {
        return ApiResponse.success(transform(data as T), statusCode: statusCode);
      } catch (e) {
        return ApiResponse.error('Transform error: ${e.toString()}', statusCode: statusCode);
      }
    }
    return ApiResponse.error(error ?? 'No data to transform', statusCode: statusCode);
  }

  /// Execute callback on success
  void onSuccess(void Function(T data) callback) {
    if (isSuccess && data != null) {
      callback(data as T);
    }
  }

  /// Execute callback on error
  void onError(void Function(String error) callback) {
    if (!isSuccess && error != null) {
      callback(error!);
    }
  }
}

/// API error model
class ApiError {
  final String detail;
  final String? errorCode;
  final DateTime? timestamp;

  const ApiError({
    required this.detail,
    this.errorCode,
    this.timestamp,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      detail: json['detail'] as String,
      errorCode: json['error_code'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  @override
  String toString() => detail;
}

/// Health check response model
class HealthCheckResponse {
  final String status;
  final String database;
  final String storage;
  final int activeJobs;
  final int maxConcurrentJobs;

  const HealthCheckResponse({
    required this.status,
    required this.database,
    required this.storage,
    required this.activeJobs,
    required this.maxConcurrentJobs,
  });

  factory HealthCheckResponse.fromJson(Map<String, dynamic> json) {
    return HealthCheckResponse(
      status: json['status'] as String,
      database: json['database'] as String,
      storage: json['storage'] as String,
      activeJobs: json['active_jobs'] as int,
      maxConcurrentJobs: json['max_concurrent_jobs'] as int,
    );
  }

  /// Check if service is healthy
  bool get isHealthy => status.toLowerCase() == 'healthy';

  /// Check if database is connected
  bool get isDatabaseConnected => database.toLowerCase() == 'connected';

  /// Check if can accept new jobs
  bool get canAcceptJobs => activeJobs < maxConcurrentJobs;

  /// Get available job slots
  int get availableSlots => maxConcurrentJobs - activeJobs;
}

