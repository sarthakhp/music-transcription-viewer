import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';

/// API error handler utility
class ApiErrorHandler {
  /// Handle HTTP response and convert to ApiResponse
  static ApiResponse<T> handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      // Success responses (2xx)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final data = fromJson(jsonData);
        return ApiResponse.success(data, statusCode: response.statusCode);
      }

      // Error responses
      return _handleErrorResponse(response);
    } catch (e) {
      return ApiResponse.error(
        'Failed to parse response: ${e.toString()}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Handle HTTP response for binary data (audio files)
  static ApiResponse<List<int>> handleBinaryResponse(http.Response response) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(
          response.bodyBytes,
          statusCode: response.statusCode,
        );
      }

      return _handleErrorResponse(response);
    } catch (e) {
      return ApiResponse.error(
        'Failed to download file: ${e.toString()}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Handle error response
  static ApiResponse<T> _handleErrorResponse<T>(http.Response response) {
    try {
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final apiError = ApiError.fromJson(jsonData);
      return ApiResponse.error(
        apiError.detail,
        statusCode: response.statusCode,
      );
    } catch (e) {
      // Fallback to generic error messages based on status code
      return ApiResponse.error(
        _getErrorMessageForStatusCode(response.statusCode),
        statusCode: response.statusCode,
      );
    }
  }

  /// Get user-friendly error message for status code
  static String _getErrorMessageForStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Unauthorized. Please log in again.';
      case 403:
        return 'Access forbidden.';
      case 404:
        return 'Resource not found.';
      case 413:
        return 'File too large. Maximum size is 100MB.';
      case 429:
        return 'Too many requests. Maximum 3 concurrent jobs allowed.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
        return 'Bad gateway. Service temporarily unavailable.';
      case 503:
        return 'Service unavailable. Please try again later.';
      case 504:
        return 'Gateway timeout. Please try again.';
      default:
        return 'An error occurred (Status: $statusCode)';
    }
  }

  /// Handle exceptions and convert to ApiResponse
  static ApiResponse<T> handleException<T>(dynamic error) {
    if (error is SocketException) {
      return ApiResponse.networkError(
        'Cannot connect to server. Please check your internet connection.',
      );
    }

    if (error is TimeoutException) {
      return ApiResponse.timeout(
        'Request timed out. The server is taking too long to respond.',
      );
    }

    if (error is FormatException) {
      return ApiResponse.error(
        'Invalid data format received from server.',
      );
    }

    if (error is http.ClientException) {
      return ApiResponse.networkError(
        'Network error: ${error.message}',
      );
    }

    // Generic error
    return ApiResponse.error(
      'An unexpected error occurred: ${error.toString()}',
    );
  }

  /// Execute API call with error handling
  static Future<ApiResponse<T>> executeApiCall<T>(
    Future<http.Response> Function() apiCall,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await apiCall();
      return handleResponse(response, fromJson);
    } catch (e) {
      return handleException(e);
    }
  }

  /// Execute binary API call with error handling
  static Future<ApiResponse<List<int>>> executeBinaryApiCall(
    Future<http.Response> Function() apiCall,
  ) async {
    try {
      final response = await apiCall();
      return handleBinaryResponse(response);
    } catch (e) {
      return handleException(e);
    }
  }

  /// Check if error is retryable
  static bool isRetryable(ApiResponse response) {
    if (response.statusCode == null) return true; // Network errors are retryable
    
    // Retry on server errors and rate limiting
    return response.statusCode! >= 500 || response.statusCode == 429;
  }
}

