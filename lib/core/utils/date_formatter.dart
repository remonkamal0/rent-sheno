import 'package:intl/intl.dart';
import 'localizations.dart';

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

  static String formatRelative(
    DateTime date, [
    AppLocalizations? localizations,
  ]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return localizations != null
          ? '${localizations.translate('today')}, ${formatTime(date)}'
          : 'Today, ${formatTime(date)}';
    } else if (compareDate == yesterday) {
      return localizations != null
          ? '${localizations.translate('yesterday')}, ${formatTime(date)}'
          : 'Yesterday, ${formatTime(date)}';
    } else if (compareDate == tomorrow) {
      return localizations != null
          ? '${localizations.translate('tomorrow')}, ${formatTime(date)}'
          : 'Tomorrow, ${formatTime(date)}';
    }

    final difference = now.difference(date).inDays;
    if (difference > 0 && difference < 7) {
      return localizations != null
          ? localizations.translate('days_ago', difference.toString())
          : '$difference days ago';
    } else if (difference < 0 && difference.abs() < 7) {
      return localizations != null
          ? localizations.translate('in_days', difference.abs().toString())
          : 'In ${difference.abs()} days';
    }

    return formatShortDate(date);
  }

  static String formatOverdueDate(
    DateTime dueDate, [
    AppLocalizations? localizations,
  ]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      final difference = today.difference(due).inDays;
      return localizations != null
          ? localizations.translate('late_status', difference.toString())
          : '$difference days late';
    } else if (due.isAfter(today)) {
      final difference = due.difference(today).inDays;
      return localizations != null
          ? localizations.translate('due_in_days', difference.toString())
          : 'Due in $difference days';
    } else {
      return localizations != null
          ? localizations.translate('due_today')
          : 'Due today';
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
