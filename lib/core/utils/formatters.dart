import 'package:intl/intl.dart';

/// Currency and number formatting utilities.
class Formatters {
  /// Formats a number as Philippine Peso (e.g., "₱1,450.00").
  static String currency(double amount, {String symbol = '₱'}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Formats a number with commas (e.g., "1,234").
  static String number(double value, {int decimalDigits = 0}) {
    final formatter = NumberFormat.decimalPattern()
      ..minimumFractionDigits = decimalDigits
      ..maximumFractionDigits = decimalDigits;
    return formatter.format(value);
  }

  /// Formats a percentage (e.g., "50.0%").
  static String percent(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  /// Formats a DateTime as a short date (e.g., "Jul 21, 2026").
  static String shortDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  /// Formats a DateTime as time only (e.g., "2:30 PM").
  static String timeOnly(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  /// Formats a DateTime as relative time (e.g., "2 hours ago").
  static String relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate(date);
  }

  /// Formats a date string from the database.
  static String fromDbString(String? dateStr, {bool timeOnly = false}) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return timeOnly ? Formatters.timeOnly(date) : shortDate(date);
    } catch (_) {
      return dateStr;
    }
  }
}
