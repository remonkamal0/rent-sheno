import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/sms_back_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/empty_state.dart';

class ManagerPaymentsScreen extends ConsumerStatefulWidget {
  const ManagerPaymentsScreen({super.key});

  @override
  ConsumerState<ManagerPaymentsScreen> createState() =>
      _ManagerPaymentsScreenState();
}

class _ManagerPaymentsScreenState extends ConsumerState<ManagerPaymentsScreen> {
  String _selectedYear = 'All';
  String _selectedBuilding = 'All';
  String _selectedResident = 'All';

  String? getBuildingName(String? unit) {
    if (unit == null) return null;
    final parts = unit.split(' - ');
    return parts.isNotEmpty ? parts[0].trim() : null;
  }

  @override
  Widget build(BuildContext context) {
    final paymentsState = ref.watch(managerPaymentsProvider);
    final tenantsState = ref.watch(managerTenantsProvider);
    final localizations = AppLocalizations.of(context);

    final tenantsList = tenantsState.value ?? [];
    final buildingsList = tenantsList
        .map((t) => getBuildingName(t.unitNumber))
        .whereType<String>()
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const SmsBackButton(),
        title: Text(localizations.translate('review_tenant_payments')),
        actions: [
          IconButton(
            icon: const Icon(
              LucideIcons.plusCircle,
              color: AppColors.primaryNavy,
            ),
            tooltip: localizations.translate('issue_rent_claim'),
            onPressed: () => context.push('/manager/payments/create'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Interactive Filters Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.slidersHorizontal,
                        size: 16,
                        color: AppColors.primaryNavy,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        localizations.translate('filter_by'),
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDropdown(
                          label: localizations.translate('year'),
                          value: _selectedYear,
                          items: ['All', '2026', '2025', '2024'],
                          itemLabel: (val) => val == 'All'
                              ? localizations.translate('all_years')
                              : val,
                          onChanged: (val) {
                            setState(() => _selectedYear = val!);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildDropdown(
                          label: localizations.translate('building'),
                          value: _selectedBuilding,
                          items: ['All', ...buildingsList],
                          itemLabel: (val) => val == 'All'
                              ? localizations.translate('all_buildings')
                              : val,
                          onChanged: (val) {
                            setState(() => _selectedBuilding = val!);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildDropdown(
                          label: localizations.translate('resident'),
                          value: _selectedResident,
                          items: ['All', ...tenantsList.map((t) => t.id)],
                          itemLabel: (val) {
                            if (val == 'All')
                              return localizations.translate('all_residents');
                            final tenant = tenantsList.firstWhere(
                              (t) => t.id == val,
                              orElse: () => UserProfile(
                                id: '',
                                fullName: val,
                                email: '',
                                role: 'tenant',
                                preferredLanguage: 'en',
                              ),
                            );
                            return tenant.fullName;
                          },
                          onChanged: (val) {
                            setState(() => _selectedResident = val!);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(managerPaymentsProvider);
                  ref.invalidate(managerTenantsProvider);
                },
                child: paymentsState.when(
                  data: (payments) {
                    final filteredPayments = payments.where((pay) {
                      if (_selectedYear != 'All') {
                        if (pay.paymentDate.year.toString() != _selectedYear) {
                          return false;
                        }
                      }
                      if (_selectedResident != 'All') {
                        if (pay.residentId != _selectedResident) {
                          return false;
                        }
                      }
                      if (_selectedBuilding != 'All') {
                        final tenant = tenantsList.firstWhere(
                          (t) => t.id == pay.residentId,
                          orElse: () => UserProfile(
                            id: '',
                            fullName: '',
                            email: '',
                            role: 'tenant',
                            preferredLanguage: 'en',
                          ),
                        );
                        final bldg = getBuildingName(tenant.unitNumber);
                        if (bldg != _selectedBuilding) {
                          return false;
                        }
                      }
                      return true;
                    }).toList();

                    if (filteredPayments.isEmpty) {
                      return ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Center(
                              child: EmptyState(
                                icon: LucideIcons.filter,
                                title: AppLocalizations.of(
                                  context,
                                ).text('No Matching Payments'),
                                description: AppLocalizations.of(context).text(
                                  'Try adjusting your filters to find payment records.',
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: filteredPayments.length,
                      itemBuilder: (context, index) {
                        final pay = filteredPayments[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(context).text(
                                          'REF: {}',
                                          pay.transactionReference ?? pay.id,
                                        ),
                                        style: AppTextStyles.label.copyWith(
                                          color: AppColors.secondaryText,
                                          fontSize: 10,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    StatusBadge(status: pay.status),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '\$${pay.amount.toStringAsFixed(2)}',
                                            style: AppTextStyles.heading2
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppLocalizations.of(context).text(
                                              'Paid via: {}',
                                              pay.paymentMethod,
                                            ),
                                            style: AppTextStyles.bodySmall,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: pay.status == 'paid'
                                            ? AppColors.lightBlue
                                            : AppColors.primaryNavy,
                                        foregroundColor: pay.status == 'paid'
                                            ? AppColors.primaryNavy
                                            : Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        if (pay.status == 'paid') {
                                          _showReceiptProofDialog(context, pay);
                                        } else {
                                          await ref
                                              .read(paymentServiceProvider)
                                              .updateChargeStatus(
                                                pay.id,
                                                'paid',
                                              );
                                          ref.invalidate(
                                            managerPaymentsProvider,
                                          );
                                          ref.invalidate(chargesProvider);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  ).text(
                                                    'Payment marked as paid successfully!',
                                                  ),
                                                ),
                                                backgroundColor:
                                                    AppColors.success,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: Icon(
                                        pay.status == 'paid'
                                            ? LucideIcons.fileSearch
                                            : LucideIcons.checkCircle,
                                        size: 14,
                                      ),
                                      label: Text(
                                        pay.status == 'paid'
                                            ? AppLocalizations.of(
                                                context,
                                              ).text('View Receipt')
                                            : AppLocalizations.of(
                                                context,
                                              ).text('Mark Paid'),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                FutureBuilder<UserProfile?>(
                                  future: ref
                                      .read(authServiceProvider)
                                      .getUserProfileById(pay.residentId),
                                  builder: (context, snapshot) {
                                    final name =
                                        snapshot.data?.fullName ??
                                        pay.residentId;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Tenant: $name',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormatter.formatRelative(
                                            pay.paymentDate,
                                            localizations,
                                          ),
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                                color: AppColors.secondaryText,
                                              ),
                                        ),
                                      ],
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
                  loading: () => ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: 4,
                    itemBuilder: (context, index) => const SkeletonCard(),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).text('Error loading payments history'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) itemLabel,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryText,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
              onChanged: onChanged,
              items: items.map((val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(itemLabel(val)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptProofDialog(BuildContext context, dynamic payment) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context).text('Verification Receipt'),
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
              child:
                  payment.receiptUrl != null &&
                      !payment.receiptUrl!.startsWith('http')
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          color: AppColors.primaryNavy,
                          size: 40,
                        ),
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
                        Text(
                          AppLocalizations.of(
                            context,
                          ).text('Uploaded Receipt Attachment'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.shieldCheck,
                          color: AppColors.success,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context).text('Verified Receipt'),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.receiptUrl != null
                              ? AppLocalizations.of(
                                  context,
                                ).text('Secured Attachment Link')
                              : AppLocalizations.of(
                                  context,
                                ).text('Secure Card Checkout'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _buildDialogRow(
              AppLocalizations.of(context).text('Ref Number'),
              payment.transactionReference ?? payment.id,
            ),
            const SizedBox(height: 8),
            _buildDialogRow(
              AppLocalizations.of(context).text('Amount Paid'),
              '\$${payment.amount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _buildDialogRow(
              AppLocalizations.of(context).text('Payment Channel'),
              payment.paymentMethod,
            ),
            const SizedBox(height: 8),
            _buildDialogRow(
              AppLocalizations.of(context).text('Payment Date'),
              DateFormatter.formatRelative(payment.paymentDate, localizations),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).text('Close'),
              style: TextStyle(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
