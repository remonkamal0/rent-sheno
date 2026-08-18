import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/localizations.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({required this.status, super.key});

  @override
  Widget build(BuildContext context) {
    final cleanStatus = status.trim().toLowerCase();
    final localizations = AppLocalizations.of(context);
    
    Color bgColor;
    Color textColor;
    String label;

    switch (cleanStatus) {
      case 'pending':
        bgColor = AppColors.warningBg;
        textColor = AppColors.warning;
        label = localizations.translate('pending');
        break;
      case 'in_progress':
      case 'in progress':
        bgColor = AppColors.lightBlue;
        textColor = AppColors.primaryNavy;
        label = localizations.translate('in_progress');
        break;
      case 'scheduled':
        bgColor = AppColors.lightBlue;
        textColor = AppColors.darkNavy;
        label = localizations.translate('scheduled');
        break;
      case 'closed':
      case 'resolved':
      case 'paid':
      case 'active':
        bgColor = AppColors.successBg;
        textColor = AppColors.success;
        label = cleanStatus == 'paid' 
            ? localizations.translate('paid') 
            : (cleanStatus == 'active' ? localizations.translate('active') : localizations.translate(cleanStatus));
        break;
      case 'cancelled':
      case 'canceled':
        bgColor = AppColors.errorBg;
        textColor = AppColors.error;
        label = localizations.translate('cancelled');
        break;
      case 'failed':
      case 'past_due':
      case 'past due':
      case 'expired':
        bgColor = AppColors.errorBg;
        textColor = AppColors.error;
        label = cleanStatus == 'expired' 
            ? localizations.translate('expired') 
            : (cleanStatus == 'past_due' || cleanStatus == 'past due' ? localizations.translate('past_due') : localizations.translate('failed'));
        break;
      case 'upcoming':
        bgColor = AppColors.lightBlue;
        textColor = AppColors.primaryNavy;
        label = localizations.translate('upcoming');
        break;
      case 'due':
        bgColor = AppColors.warningBg;
        textColor = AppColors.warning;
        label = localizations.translate('due');
        break;
      default:
        bgColor = AppColors.border.withOpacity(0.3);
        textColor = AppColors.secondaryText;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
