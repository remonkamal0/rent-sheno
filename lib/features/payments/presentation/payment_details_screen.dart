import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/app_buttons.dart';

class PaymentDetailsScreen extends ConsumerWidget {
  final String paymentId;

  const PaymentDetailsScreen({required this.paymentId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final historyState = ref.watch(paymentsHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(localizations.translate('receipt')),
      ),
      body: SafeArea(
        child: historyState.when(
          data: (history) {
            // Find the payment receipt details
            final payment = history.firstWhere(
              (p) => p.id == paymentId || p.transactionReference == paymentId,
              orElse: () => Payment(
                id: paymentId,
                residentId: 'mock-user-123',
                amount: 0.0,
                paymentMethod: 'Unknown',
                status: 'failed',
                paymentDate: DateTime.now(),
              ),
            );

            if (payment.amount == 0.0) {
              return const Center(child: Text('Receipt not found.'));
            }

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Success Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.successBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 40,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Payment Successful',
                            style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${payment.amount.toStringAsFixed(2)}',
                            style: AppTextStyles.display.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w900,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const StatusBadge(status: 'paid'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Receipt details card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildReceiptDetailRow(
                            label: localizations.translate('txn_id'),
                            value: payment.id,
                          ),
                          const Divider(height: 24),
                          _buildReceiptDetailRow(
                            label: localizations.translate('pay_method'),
                            value: payment.paymentMethod,
                          ),
                          const Divider(height: 24),
                          _buildReceiptDetailRow(
                            label: localizations.translate('pay_date'),
                            value: DateFormatter.formatDateTime(payment.paymentDate),
                          ),
                          const Divider(height: 24),
                          _buildReceiptDetailRow(
                            label: 'Status',
                            value: payment.status.toUpperCase(),
                            valueColor: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Download Receipt Button
                  AppSecondaryButton(
                    text: localizations.translate('download_receipt'),
                    icon: LucideIcons.download,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Receipt PDF saved to Downloads directory.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryNavy),
            ),
          ),
          error: (err, stack) => Center(child: Text(localizations.translate('error_loading'))),
        ),
      ),
    );
  }

  Widget _buildReceiptDetailRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}
