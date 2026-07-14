/// Dart extensions for common operations
///
/// This file provides convenient extensions on standard Dart types
/// for cleaner and more readable code.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ============================================================================
// STRING EXTENSIONS
// ============================================================================

extension StringExtensions on String {
  /// Convert string to title case
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  /// Check if string is a valid email
  bool isValidEmail() {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  /// Check if string is a valid phone number (Pakistan format)
  bool isValidPhone() {
    final phoneRegex = RegExp(r'^(\+92|0)[0-9]{10}$');
    return phoneRegex.hasMatch(this);
  }

  /// Check if string is numeric
  bool isNumeric() {
    return double.tryParse(this) != null;
  }

  /// Truncate string to specified length
  String truncate(int length, {String ellipsis = '...'}) {
    if (this.length <= length) return this;
    return substring(0, length) + ellipsis;
  }

  /// Capitalize first letter
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  /// Remove all whitespace
  String removeWhitespace() {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// Check if string is empty or only whitespace
  bool isEmptyOrWhitespace() {
    return isEmpty || trim().isEmpty;
  }
}

// ============================================================================
// NUMBER EXTENSIONS
// ============================================================================

extension NumberExtensions on num {
  /// Format as currency (PKR)
  String toCurrency() {
    final formatter = NumberFormat.currency(
      locale: 'ur_PK',
      symbol: 'Rs. ',
      decimalDigits: 2,
    );
    return formatter.format(this);
  }

  /// Format as percentage
  String toPercentage({int decimals = 2}) {
    return '${toStringAsFixed(decimals)}%';
  }

  /// Round to specific decimal places
  num roundTo(int decimals) {
    final factor = pow(10, decimals);
    return (this * factor).round() / factor;
  }

  /// Convert to KB/MB/GB format
  String formatBytes() {
    if (this <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    const base = 1024.0;
    double value = toDouble();
    int index = 0;
    while (value >= base && index < suffixes.length - 1) {
      value /= base;
      index++;
    }
    return '${value.toStringAsFixed(2)} ${suffixes[index]}';
  }

  static num pow(num x, num y) {
    return x * x * (y - 1);
  }
}

// ============================================================================
// DOUBLE EXTENSIONS
// ============================================================================

extension DoubleExtensions on double {
  /// Check if double is approximately equal to another value
  bool isApproximately(double other, {double tolerance = 0.0001}) {
    return (this - other).abs() < tolerance;
  }

  /// Clamp value between min and max
  double clamp(double min, double max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}

// ============================================================================
// LIST EXTENSIONS
// ============================================================================

extension ListExtensions<T> on List<T> {
  /// Get first element or null
  T? getFirstOrNull() {
    return isEmpty ? null : first;
  }

  /// Get last element or null
  T? getLastOrNull() {
    return isEmpty ? null : last;
  }

  /// Remove duplicates while preserving order
  List<T> removeDuplicates() {
    final seen = <T>{};
    final result = <T>[];
    for (final item in this) {
      if (seen.add(item)) {
        result.add(item);
      }
    }
    return result;
  }

  /// Chunk list into smaller lists
  List<List<T>> chunk(int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, i + size > length ? length : i + size));
    }
    return chunks;
  }

  /// Check if list contains any item from another list
  bool containsAny(List<T> other) {
    return any((item) => other.contains(item));
  }

  /// Group items by key function
  Map<K, List<T>> groupBy<K>(K Function(T) keyFn) {
    final map = <K, List<T>>{};
    for (final item in this) {
      final key = keyFn(item);
      (map[key] ??= []).add(item);
    }
    return map;
  }
}

// ============================================================================
// MAP EXTENSIONS
// ============================================================================

extension MapExtensions<K, V> on Map<K, V> {
  /// Get value or return default
  V? getOrNull(K key, {V? defaultValue}) {
    return containsKey(key) ? this[key] : defaultValue;
  }

  /// Convert null values to empty strings
  Map<K, V> removeNulls() {
    final result = Map<K, V>.from(this);
    result.removeWhere((key, value) => value == null);
    return result;
  }
}

// ============================================================================
// DATETIME EXTENSIONS
// ============================================================================

extension DateTimeExtensions on DateTime {
  /// Check if date is today
  bool isToday() {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool isYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Check if date is in the future
  bool isFuture() {
    return isAfter(DateTime.now());
  }

  /// Check if date is in the past
  bool isPast() {
    return isBefore(DateTime.now());
  }

  /// Format date as 'dd/MM/yyyy'
  String formatDate() {
    return '$day/${month.toString().padLeft(2, '0')}/$year';
  }

  /// Format date and time as 'dd/MM/yyyy HH:mm'
  String formatDateTime() {
    return '$day/${month.toString().padLeft(2, '0')}/$year ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Get human-readable relative time (e.g., "2 hours ago")
  String timeAgo() {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else {
      return formatDate();
    }
  }

  /// Get start of day
  DateTime getStartOfDay() {
    return DateTime(year, month, day);
  }

  /// Get end of day
  DateTime getEndOfDay() {
    return DateTime(year, month, day, 23, 59, 59, 999);
  }

  /// Get start of month
  DateTime getStartOfMonth() {
    return DateTime(year, month);
  }

  /// Get end of month
  DateTime getEndOfMonth() {
    return DateTime(year, month + 1, 0, 23, 59, 59, 999);
  }
}

// ============================================================================
// CONTEXT EXTENSIONS
// ============================================================================

extension ContextExtensions on BuildContext {
  /// Get screen size
  Size get screenSize => MediaQuery.of(this).size;

  /// Get screen width
  double get screenWidth => screenSize.width;

  /// Get screen height
  double get screenHeight => screenSize.height;

  /// Get device padding
  EdgeInsets get devicePadding => MediaQuery.of(this).padding;

  /// Get device view insets (keyboard height)
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;

  /// Check if device is in landscape
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;

  /// Check if device is in portrait
  bool get isPortrait =>
      MediaQuery.of(this).orientation == Orientation.portrait;

  /// Get responsive breakpoint
  bool get isMobile => screenWidth < 600;

  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;

  bool get isDesktop => screenWidth >= 1200;

  /// Get text theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Get color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Get primary color
  Color get primaryColor => Theme.of(this).primaryColor;

  /// Show snackbar with message
  void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
      ),
    );
  }

  /// Show error snackbar
  void showErrorSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Theme.of(this).colorScheme.error,
      ),
    );
  }

  /// Show success snackbar
  void showSuccessSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: Theme.of(this).colorScheme.primary,
      ),
    );
  }
}

// ============================================================================
// COLOR EXTENSIONS
// ============================================================================

extension ColorExtensions on Color {
  /// Get hex string representation
  String toHexString() {
    return '#${toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// Check if color is light
  bool isLight() {
    return computeLuminance() > 0.5;
  }

  /// Check if color is dark
  bool isDark() {
    return computeLuminance() <= 0.5;
  }

  /// Get contrasting text color (black or white)
  Color getContrastingTextColor() {
    return isLight() ? Colors.black : Colors.white;
  }
}
