import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String formatShortDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'Today, ${formatTime(date)}';
    } else if (compareDate == yesterday) {
      return 'Yesterday, ${formatTime(date)}';
    } else if (compareDate == tomorrow) {
      return 'Tomorrow, ${formatTime(date)}';
    }

    final difference = now.difference(date).inDays;
    if (difference > 0 && difference < 7) {
      return '$difference days ago';
    } else if (difference < 0 && difference.abs() < 7) {
      return 'In ${difference.abs()} days';
    }

    return formatShortDate(date);
  }

  static String formatOverdueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      final difference = today.difference(due).inDays;
      return '$difference days late';
    } else if (due.isAfter(today)) {
      final difference = due.difference(today).inDays;
      return 'Due in $difference days';
    } else {
      return 'Due today';
    }
  }

  static String formatExpiryDate(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

    if (expiry.isBefore(today)) {
      return 'Expired';
    } else {
      final difference = expiry.difference(today).inDays;
      if (difference <= 30) {
        return 'Expiring in $difference days';
      }
      return 'Active';
    }
  }
}
