import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/empty_state.dart';

class ManagerPaymentsScreen extends ConsumerWidget {
  const ManagerPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsState = ref.watch(managerPaymentsProvider);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Review Tenant Payments'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plusCircle, color: AppColors.primaryNavy),
            tooltip: 'Issue Rent Claim',
            onPressed: () => context.push('/manager/payments/create'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(managerPaymentsProvider),
          child: paymentsState.when(
            data: (payments) {
              if (payments.isEmpty) {
                return EmptyState(
                  icon: LucideIcons.creditCard,
                  title: 'No Payments Yet',
                  description: 'No transactions have been recorded or submitted by residents.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final pay = payments[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'REF: ${pay.transactionReference ?? pay.id}',
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.secondaryText,
                                  fontSize: 10,
                                ),
                              ),
                              StatusBadge(status: pay.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\$${pay.amount.toStringAsFixed(2)}',
                                    style: AppTextStyles.heading2.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Paid via: ${pay.paymentMethod}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.lightBlue,
                                  foregroundColor: AppColors.primaryNavy,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  _showReceiptProofDialog(context, pay);
                                },
                                icon: const Icon(LucideIcons.fileSearch, size: 14),
                                label: const Text('View Receipt'),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tenant: ${pay.residentId.toUpperCase()}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormatter.formatRelative(pay.paymentDate, localizations),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.secondaryText,
                                ),
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
              padding: const EdgeInsets.all(24),
              itemCount: 4,
              itemBuilder: (context, index) => const SkeletonCard(),
            ),
            error: (err, _) => const Center(child: Text('Error loading payments history')),
          ),
        ),
      ),
    );
  }

  void _showReceiptProofDialog(BuildContext context, dynamic payment) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Verification Receipt',
          style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: payment.receiptUrl != null && !payment.receiptUrl!.startsWith('http')
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.fileText, color: AppColors.primaryNavy, size: 40),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            payment.receiptUrl!.split('/').last,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Uploaded Receipt Attachment', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.shieldCheck, color: AppColors.success, size: 40),
                        const SizedBox(height: 12),
                        const Text('Verified Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(payment.receiptUrl != null ? 'Secured Attachment Link' : 'Secure Card Checkout', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _buildDialogRow('Ref Number', payment.transactionReference ?? payment.id),
            const SizedBox(height: 8),
            _buildDialogRow('Amount Paid', '\$${payment.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildDialogRow('Payment Channel', payment.paymentMethod),
            const SizedBox(height: 8),
            _buildDialogRow('Payment Date', DateFormatter.formatRelative(payment.paymentDate, localizations)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
