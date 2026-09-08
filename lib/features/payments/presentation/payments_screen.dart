import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/sms_app_bar.dart';
import '../../../core/widgets/sms_drawer.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/skeleton_loading.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final chargesState = ref.watch(chargesProvider);

    return Scaffold(
      appBar: const SmsAppBar(),
      drawer: const SmsDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.translate('payments'),
                  style: AppTextStyles.heading1,
                ),
                const SizedBox(height: 6),
                Text(
                  localizations.translate('manage_balance'),
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Rent Months List
          Expanded(
            child: chargesState.when(
              data: (charges) {
                final paidByMonth = <String, Charge>{};
                for (final charge in charges.where(
                  (item) => item.status == 'paid' && item.chargeType == 'rent',
                )) {
                  final monthKey =
                      '${charge.dueDate.year}-${charge.dueDate.month}';
                  paidByMonth[monthKey] = charge;
                }
                final paidCharges = paidByMonth.values.toList();

                if (paidCharges.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).text('No confirmed rent payments yet.'),
                    ),
                  );
                }

                // Only owner-confirmed rent months are visible to the tenant.
                final sortedCharges = List<Charge>.from(paidCharges)
                  ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedCharges.length,
                  itemBuilder: (context, index) {
                    final charge = sortedCharges[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.successBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    LucideIcons.check,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayTitle(charge, localizations),
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _displaySubtitle(charge, localizations),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${charge.totalAmount.toStringAsFixed(2)}',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                    if (charge.lateFee > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          localizations.locale.languageCode == 'ar'
                                              ? '(يشمل \$${charge.lateFee.toStringAsFixed(2)} غرامة تأخير)'
                                              : '(Incl. \$${charge.lateFee.toStringAsFixed(2)} late fee)',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            fontSize: 10,
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    StatusBadge(
                                      status: charge.status == 'paid'
                                          ? 'paid'
                                          : charge.calculatedStatus,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (context, index) => const SkeletonCard(),
              ),
              error: (err, stack) =>
                  Center(child: Text(localizations.translate('error_loading'))),
            ),
          ),
        ],
      ),
    );
  }

  String _displayTitle(Charge charge, AppLocalizations localizations) {
    if (charge.chargeType == 'rent') {
      final monthStr = DateFormatter.formatMonthYear(charge.dueDate);
      return localizations.locale.languageCode == 'ar'
          ? 'إيجار $monthStr'
          : '$monthStr Rent';
    }
    return charge.title;
  }

  String _displaySubtitle(Charge charge, AppLocalizations localizations) {
    if (charge.status == 'paid') {
      return localizations.locale.languageCode == 'ar'
          ? 'تم تأكيد الدفع من المالك'
          : 'Payment confirmed by owner';
    }
    return '${localizations.translate('due')}: ${DateFormatter.formatOverdueDate(charge.dueDate, localizations)}';
  }
}
