import 'package:intl/intl.dart';
import 'localizations.dart';

class DateFormatter {
  DateFormatter._();

  static String formatShortDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date.toLocal());
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date.toLocal());
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy h:mm a').format(date.toLocal());
  }

  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date.toLocal());
  }

  static String formatRelative(
    DateTime date, [
    AppLocalizations? localizations,
  ]) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final compareDate = DateTime(localDate.year, localDate.month, localDate.day);

    if (compareDate == today) {
      return localizations != null
          ? '${localizations.translate('today')}, ${formatTime(localDate)}'
          : 'Today, ${formatTime(localDate)}';
    } else if (compareDate == yesterday) {
      return localizations != null
          ? '${localizations.translate('yesterday')}, ${formatTime(localDate)}'
          : 'Yesterday, ${formatTime(localDate)}';
    } else if (compareDate == tomorrow) {
      return localizations != null
          ? '${localizations.translate('tomorrow')}, ${formatTime(localDate)}'
          : 'Tomorrow, ${formatTime(localDate)}';
    }

    final diffDays = today.difference(compareDate).inDays;
    if (diffDays > 0 && diffDays < 7) {
      return localizations != null
          ? '${localizations.translate('days_ago', diffDays.toString())}, ${formatTime(localDate)}'
          : '$diffDays days ago, ${formatTime(localDate)}';
    } else if (diffDays < 0 && diffDays.abs() < 7) {
      return localizations != null
          ? '${localizations.translate('in_days', diffDays.abs().toString())}, ${formatTime(localDate)}'
          : 'In ${diffDays.abs()} days, ${formatTime(localDate)}';
    }

    return formatDateTime(localDate);
  }

  static String formatOverdueDate(
    DateTime dueDate, [
    AppLocalizations? localizations,
  ]) {
    final localDue = dueDate.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(localDue.year, localDue.month, localDue.day);

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
    final localExpiry = expiryDate.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(localExpiry.year, localExpiry.month, localExpiry.day);

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
