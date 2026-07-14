import 'package:intl/intl.dart';

/// Utility class for common formatting operations used across the app.
class Formatters {
  /// Currency formatter for Pakistani Rupee
  static final _currencyFormatter = NumberFormat('#,##0', 'en_US');

  /// Format a double as a Pakistani Rupee currency string (e.g. "Rs. 1,250")
  static String currency(double amount) {
    return 'Rs. ${_currencyFormatter.format(amount)}';
  }

  /// Format a double with 2 decimal places (e.g. "1,250.50")
  static String decimal(double amount, {int decimalDigits = 2}) {
    return NumberFormat('#,##0.${'0' * decimalDigits}', 'en_US').format(amount);
  }

  /// Format a DateTime as a short date string (e.g. "13-07-2026")
  static String shortDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  /// Format a DateTime as a full date-time string (e.g. "13 Jul 2026, 14:30")
  static String fullDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  /// Format a DateTime as a time string only (e.g. "14:30")
  static String timeOnly(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Format a number as compact (e.g. 1500 → "1.5K", 1200000 → "1.2M")
  static String compact(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  /// Capitalize the first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
