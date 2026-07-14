/// Comprehensive error handling for the application
///
/// This module provides custom exceptions and error handling utilities
/// for better error management and user feedback.
library;

import 'package:flutter/foundation.dart';

// ============================================================================
// CUSTOM EXCEPTIONS
// ============================================================================

/// Base exception class for all application exceptions
abstract class AppException implements Exception {
  /// Error message shown to users
  final String message;

  /// Technical error details (for debugging)
  final String? technicalMessage;

  /// Original exception (if any)
  final Exception? originalException;

  /// Stack trace for debugging
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.technicalMessage,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() => message;

  /// Get full error info for logging
  String getFullErrorInfo() {
    return '''
Error: $message
Technical: $technicalMessage
Original: $originalException
Trace: $stackTrace
''';
  }
}

/// Exception thrown when network is unavailable
class NetworkException extends AppException {
  NetworkException({
    super.message = 'Network connection error',
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when server returns an error
class ServerException extends AppException {
  final int? statusCode;

  ServerException({
    required super.message,
    this.statusCode,
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when user is not authenticated
class AuthenticationException extends AppException {
  AuthenticationException({
    super.message = 'Authentication failed',
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when user lacks permissions
class AuthorizationException extends AppException {
  AuthorizationException({
    super.message = 'You do not have permission to perform this action',
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when requested resource is not found
class NotFoundException extends AppException {
  NotFoundException({
    super.message = 'Resource not found',
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when validation fails
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException({
    required super.message,
    this.fieldErrors,
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when resource already exists
class ConflictException extends AppException {
  ConflictException({
    super.message = 'This resource already exists',
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when database operation fails
class DatabaseException extends AppException {
  DatabaseException({
    required super.message,
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when file operation fails
class FileException extends AppException {
  FileException({
    required super.message,
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Exception thrown when operation times out
class TimeoutException extends AppException {
  TimeoutException({
    super.message = 'Operation timed out',
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

/// Generic exception for unexpected errors
class UnknownException extends AppException {
  UnknownException({
    super.message = 'An unexpected error occurred',
    super.technicalMessage,
    super.originalException,
    super.stackTrace,
  });
}

// ============================================================================
// ERROR RESULT WRAPPER
// ============================================================================

/// Result wrapper for operations that can fail
/// Uses Either pattern: Left for failure, Right for success
abstract class Result<L, R> {
  const Result();

  /// Execute different callbacks based on result
  T fold<T>(
    T Function(L left) onLeft,
    T Function(R right) onRight,
  );

  /// Map success value
  Result<L, T> map<T>(T Function(R right) f);

  /// Map error value
  Result<T, R> mapError<T>(T Function(L left) f);
}

/// Failure result
class Failure<L, R> extends Result<L, R> {
  final L value;

  const Failure(this.value);

  @override
  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) {
    return onLeft(value);
  }

  @override
  Result<L, T> map<T>(T Function(R right) f) => Failure(value);

  @override
  Result<T, R> mapError<T>(T Function(L left) f) => Failure(f(value));
}

/// Success result
class Success<L, R> extends Result<L, R> {
  final R value;

  const Success(this.value);

  @override
  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) {
    return onRight(value);
  }

  @override
  Result<L, T> map<T>(T Function(R right) f) => Success(f(value));

  @override
  Result<T, R> mapError<T>(T Function(L left) f) => Success(value);
}

// ============================================================================
// ERROR HANDLER
// ============================================================================

/// Utility class for error handling and conversion
class ErrorHandler {
  /// Convert any exception to AppException
  static AppException handleException(
    dynamic error, {
    StackTrace? stackTrace,
  }) {
    debugPrint('Error Handler: $error\nStackTrace: $stackTrace');

    if (error is AppException) {
      return error;
    }

    if (error is ServerException) {
      return error;
    }

    if (error is FormatException) {
      return ValidationException(
        message: 'Invalid data format',
        technicalMessage: error.message,
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    return UnknownException(
      message: 'An unexpected error occurred',
      technicalMessage: error.toString(),
      originalException: error is Exception ? error : null,
      stackTrace: stackTrace,
    );
  }

  /// Get user-friendly error message
  static String getUserMessage(AppException exception) {
    return exception.message;
  }

  /// Log error with context
  static void logError(
    AppException exception, {
    String? context,
  }) {
    if (kDebugMode) {
      print('==== ERROR ====');
      print('Context: $context');
      print(exception.getFullErrorInfo());
      print('==== END ERROR ====');
    }
  }
}
