import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
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
import '../../../core/widgets/app_buttons.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  int _activeTab = 0; // 0: Balance & Charges, 1: History

  Future<void> _showCheckoutSheet(BuildContext context, double amount, List<String> chargeIds) async {
    final localizations = AppLocalizations.of(context);
    String selectedMethod = 'Bank Transfer';
    PlatformFile? pickedFile;
    final notesController = TextEditingController();
    bool isPicking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            const requiresReceipt = true;

            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                     Text(
                      localizations.translate('confirm_payment'),
                      style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations.translate('payment_method_desc'),
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    
                    // Total due indicator
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            localizations.translate('total_due'),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: AppTextStyles.heading2.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
  
                    // Payment method selector
                    Text(
                      localizations.translate('select_payment_method').toUpperCase(),
                      style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 10),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (Wire Deposit)')),
                        DropdownMenuItem(value: 'Cash Deposit', child: Text('Cash Payment / Handover')),
                        DropdownMenuItem(value: 'Other manual method', child: Text('Other Manual Transfer')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedMethod = val);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Payment reference details notes
                    Text(
                      localizations.translate('txn_id').toUpperCase(),
                      style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Sent from HSBC account under John Doe',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                  // Receipt Upload Section (Conditional)
                  if (requiresReceipt) ...[
                    Text(
                      localizations.translate('proof_of_payment'),
                      style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isPicking
                          ? null
                          : () async {
                              setModalState(() => isPicking = true);
                              try {
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['jpg', 'png', 'pdf'],
                                );
                                if (result != null) {
                                  setModalState(() {
                                    pickedFile = result.files.first;
                                  });
                                }
                              } catch (e) {
                                debugPrint('Error picking file: $e');
                              } finally {
                                setModalState(() => isPicking = false);
                              }
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              pickedFile != null ? LucideIcons.fileCheck : LucideIcons.uploadCloud,
                              color: pickedFile != null ? AppColors.success : AppColors.primaryNavy,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                             Expanded(
                              child: Text(
                                pickedFile != null
                                    ? pickedFile!.name
                                    : localizations.translate('attach_payment_receipt'),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: pickedFile != null ? AppColors.success : AppColors.secondaryText,
                                  fontWeight: pickedFile != null ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (pickedFile != null)
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 18),
                                onPressed: () {
                                  setModalState(() {
                                    pickedFile = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Confirm button
                  AppPrimaryButton(
                    text: localizations.translate('send_amount', '\$${amount.toStringAsFixed(2)}'),
                    onTap: () async {
                      if (requiresReceipt && pickedFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please upload your transaction receipt proof!'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      final methodDetails = notesController.text.trim().isNotEmpty
                          ? '$selectedMethod (${notesController.text.trim()})'
                          : selectedMethod;

                      Navigator.pop(context); // Close sheet
                      _processPayment(
                        chargeIds,
                        amount,
                        methodDetails,
                        pickedFile?.path ?? 'https://example.com/receipts/proof.png',
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
    );
  }



  Future<void> _processPayment(List<String> chargeIds, double amount, String method, String? receiptUrl) async {
    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryNavy),
        ),
      ),
    );

    try {
      final notifier = ref.read(paymentsHistoryProvider.notifier);
      await notifier.payCharges(
        chargeIds: chargeIds,
        amount: amount,
        method: method,
        receiptUrl: receiptUrl,
      );

      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  void _showSuccessDialog() {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(
          Icons.check_circle_outline_rounded,
          size: 56,
          color: AppColors.success,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              localizations.translate('submission_success'),
              style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.translate('submission_success_desc'),
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _activeTab = 1; // Go to History tab
                });
              },
              child: Text(
                localizations.translate('view_transaction'),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final chargesState = ref.watch(chargesProvider);
    final historyState = ref.watch(paymentsHistoryProvider);

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

          // Tabs Selector
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabItem(
                    label: localizations.translate('balance_charges'),
                    isSelected: _activeTab == 0,
                    onTap: () => setState(() => _activeTab = 0),
                  ),
                ),
                Expanded(
                  child: _buildTabItem(
                    label: localizations.translate('payment_history'),
                    isSelected: _activeTab == 1,
                    onTap: () => setState(() => _activeTab = 1),
                  ),
                ),
              ],
            ),
          ),

          // Tab View Body
          Expanded(
            child: _activeTab == 0
                ? _buildBalanceTab(chargesState, localizations)
                : _buildHistoryTab(historyState, localizations),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  bottom: BorderSide(color: AppColors.primaryNavy, width: 2),
                )
              : null,
        ),
        child: Text(
          label,
          style: isSelected
              ? AppTextStyles.heading3.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                )
              : AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
        ),
      ),
    );
  }

  Widget _buildBalanceTab(AsyncValue<List<Charge>> state, AppLocalizations localizations) {
    return state.when(
      data: (charges) {
        final unpaidCharges = charges.where((c) => c.status != 'paid').toList();
        if (unpaidCharges.isEmpty) {
          return const Center(
            child: Text('You\'re all caught up! No outstanding balance.'),
          );
        }

        final double totalDue = unpaidCharges.fold(0.0, (sum, c) => sum + c.amount);
        
        // Find closest due date
        unpaidCharges.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final nearestCharge = unpaidCharges.first;
        final dueStatusText = DateFormatter.formatOverdueDate(nearestCharge.dueDate, localizations);
        final bool isLate = nearestCharge.calculatedStatus == 'past_due';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Current Balance Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations.translate('current_balance').toUpperCase(),
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.secondaryText,
                            fontSize: 11,
                          ),
                        ),
                        // Status Badge
                        StatusBadge(status: isLate ? 'past_due' : 'due'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '\$${totalDue.toStringAsFixed(2)}',
                      style: AppTextStyles.display.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 8),
                    Text(
                      dueStatusText,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isLate ? AppColors.error : AppColors.primaryNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Breakdown of Charges Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.translate('charge_breakdown'),
                      style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Render charges breakdown list
                    ...unpaidCharges.map((charge) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    charge.title,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                  if (charge.description != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      charge.description!,
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ]
                                ],
                              ),
                            ),
                            Text(
                              '\$${charge.amount.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 12),

                    // Total due row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations.translate('total_due'),
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${totalDue.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Pay Now CTA
                    AppPrimaryButton(
                      text: localizations.translate('pay_now'),
                      onTap: () {
                        final ids = unpaidCharges.map((c) => c.id).toList();
                        _showCheckoutSheet(context, totalDue, ids);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonContainer(width: double.infinity, height: 130),
          SizedBox(height: 16),
          SkeletonCard(),
        ],
      ),
      error: (err, stack) => Center(child: Text(localizations.translate('error_loading'))),
    );
  }

  Widget _buildHistoryTab(AsyncValue<List<Payment>> state, AppLocalizations localizations) {
    return state.when(
      data: (history) {
        if (history.isEmpty) {
          return const Center(child: Text('No payment history found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final payment = history[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.successBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${payment.amount.toStringAsFixed(2)}',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormatter.formatShortDate(payment.paymentDate),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const StatusBadge(status: 'paid'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => context.push('/payments/${payment.id}'),
                          child: Text(
                            localizations.translate('receipt'),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryNavy,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
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
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) => const SkeletonCard(),
      ),
      error: (err, stack) => Center(child: Text(localizations.translate('error_loading'))),
    );
  }
}
