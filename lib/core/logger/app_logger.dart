/// Application Logger
///
/// Comprehensive logging system for development and debugging.
/// Logs are categorized by type and can be filtered in production.
library;
// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// Log levels
enum LogLevel { verbose, debug, info, warning, error }

/// Log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get formattedTime =>
      "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";

  String get formattedLog =>
      '[$formattedTime] [${level.name.toUpperCase()}] [$tag] $message';

  @override
  String toString() => formattedLog;
}

/// Application Logger - Singleton
class AppLogger {
  static const int maxLogs = 1000;
  static final AppLogger _instance = AppLogger._internal();
  static final List<LogEntry> _logs = [];
  static LogLevel _minLogLevel = LogLevel.debug;

  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal();

  /// Set minimum log level
  static void setMinLogLevel(LogLevel level) {
    _minLogLevel = level;
  }

  /// Log verbose message
  static void verbose(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.verbose, tag, message, error, stackTrace);
  }

  /// Log debug message
  static void debug(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.debug, tag, message, error, stackTrace);
  }

  /// Log info message
  static void info(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.info, tag, message, error, stackTrace);
  }

  /// Log warning message
  static void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.warning, tag, message, error, stackTrace);
  }

  /// Log error message
  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.error, tag, message, error, stackTrace);
  }

  /// Internal log method
  static void _log(
    LogLevel level,
    String tag,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // Skip if below minimum log level
    if (level.index < _minLogLevel.index) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    // Store in memory
    _logs.add(entry);
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }

    // Print to console in debug mode
    if (kDebugMode) {
      _printLog(entry);
    }

    // Send to developer tools
    if (level.index >= LogLevel.error.index) {
      developer.log(
        entry.formattedLog,
        time: entry.timestamp,
        name: tag,
        level: level.index,
      );
    }
  }

  /// Print log to console
  static void _printLog(LogEntry entry) {
    final prefix =
        '${entry.level.name.toUpperCase().padRight(7)} | ${entry.tag.padRight(15)}';

    switch (entry.level) {
      case LogLevel.verbose:
        print('▼ $prefix | ${entry.message}');
        break;
      case LogLevel.debug:
        print('▽ $prefix | ${entry.message}');
        break;
      case LogLevel.info:
        print('ℹ️  $prefix | ${entry.message}');
        break;
      case LogLevel.warning:
        print('⚠️  $prefix | ${entry.message}');
        break;
      case LogLevel.error:
        print('❌ $prefix | ${entry.message}');
        if (entry.error != null) {
          print('   Error: ${entry.error}');
        }
        if (entry.stackTrace != null) {
          print('   StackTrace: ${entry.stackTrace}');
        }
        break;
    }
  }

  /// Get all logs
  static List<LogEntry> getLogs() => List.from(_logs);

  /// Get logs by level
  static List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Get logs by tag
  static List<LogEntry> getLogsByTag(String tag) {
    return _logs.where((log) => log.tag == tag).toList();
  }

  /// Clear all logs
  static void clearLogs() {
    _logs.clear();
  }

  /// Export logs as formatted string
  static String exportLogs({LogLevel? minLevel, String? tagFilter}) {
    List<LogEntry> filtered = _logs;

    if (minLevel != null) {
      filtered = filtered
          .where((log) => log.level.index >= minLevel.index)
          .toList();
    }

    if (tagFilter != null) {
      filtered = filtered.where((log) => log.tag.contains(tagFilter)).toList();
    }

    return filtered.map((log) => log.formattedLog).join('\n');
  }

  /// Log method execution time (for performance debugging)
  static Future<T> logExecutionTime<T>(
    String tag,
    String methodName,
    Future<T> Function() function, {
    int warnThresholdMs = 1000,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await function();
      stopwatch.stop();

      final message =
          '$methodName executed in ${stopwatch.elapsedMilliseconds}ms';
      if (stopwatch.elapsedMilliseconds > warnThresholdMs) {
        warning(tag, '⏱️  $message (slow)');
      } else {
        debug(tag, '⏱️  $message');
      }

      return result;
    } catch (e, st) {
      stopwatch.stop();
      error(
        tag,
        '$methodName failed after ${stopwatch.elapsedMilliseconds}ms',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Log synchronous method execution time
  static T logSyncExecutionTime<T>(
    String tag,
    String methodName,
    T Function() function, {
    int warnThresholdMs = 100,
  }) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = function();
      stopwatch.stop();

      final message =
          '$methodName executed in ${stopwatch.elapsedMilliseconds}ms';
      if (stopwatch.elapsedMilliseconds > warnThresholdMs) {
        warning(tag, '⏱️  $message (slow)');
      } else {
        debug(tag, '⏱️  $message');
      }

      return result;
    } catch (e, st) {
      stopwatch.stop();
      error(
        tag,
        '$methodName failed after ${stopwatch.elapsedMilliseconds}ms',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}

/// Shorthand convenience methods
void vLog(String tag, String message) => AppLogger.verbose(tag, message);
void dLog(String tag, String message) => AppLogger.debug(tag, message);
void iLog(String tag, String message) => AppLogger.info(tag, message);
void wLog(String tag, String message) => AppLogger.warning(tag, message);
void eLog(String tag, String message, {Object? error, StackTrace? st}) =>
    AppLogger.error(tag, message, error: error, stackTrace: st);
