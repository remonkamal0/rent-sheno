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
                if (charges.isEmpty) {
                  return const Center(
                    child: Text('No rent history found.'),
                  );
                }

                // Sort by due date descending (latest first)
                final sortedCharges = List<Charge>.from(charges)
                  ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedCharges.length,
                  itemBuilder: (context, index) {
                    final charge = sortedCharges[index];
                    final isLate = charge.calculatedStatus == 'past_due';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: charge.status == 'paid'
                                    ? AppColors.successBg
                                    : (isLate ? AppColors.errorBg : AppColors.warningBg),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                charge.status == 'paid'
                                    ? LucideIcons.check
                                    : (isLate ? LucideIcons.alertTriangle : LucideIcons.calendar),
                                color: charge.status == 'paid'
                                    ? AppColors.success
                                    : (isLate ? AppColors.error : AppColors.warning),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    charge.title,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${localizations.translate('due')}: ${DateFormatter.formatOverdueDate(charge.dueDate, localizations)}',
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
                                  '\$${charge.amount.toStringAsFixed(2)}',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryNavy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                StatusBadge(status: charge.status == 'paid' ? 'paid' : charge.calculatedStatus),
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
              error: (err, stack) => Center(
                child: Text(localizations.translate('error_loading')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
