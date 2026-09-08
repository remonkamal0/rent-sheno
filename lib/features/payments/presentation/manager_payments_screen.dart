import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/sms_back_button.dart';

class ManagerPaymentsScreen extends ConsumerStatefulWidget {
  const ManagerPaymentsScreen({super.key});
  @override
  ConsumerState<ManagerPaymentsScreen> createState() => _ManagerPaymentsScreenState();
}

class _ManagerPaymentsScreenState extends ConsumerState<ManagerPaymentsScreen> {
  String _resident = 'All';
  String _year = 'All';
  String _viewScope = 'current_upcoming'; // 'current_upcoming' | 'all' | 'unpaid'
  final Set<String> _showAllForResident = {};
  final Set<String> _expanded = {};
  final Set<String> _saving = {};

  @override
  Widget build(BuildContext context) {
    final rents = ref.watch(managerRentChargesProvider);
    final tenants = ref.watch(managerTenantsProvider).value ?? <UserProfile>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const SmsBackButton(), title: const Text('Tenant rent payments'),
        actions: [IconButton(tooltip: 'Create another charge', onPressed: () => context.push('/manager/payments/create'), icon: const Icon(LucideIcons.plusCircle, color: AppColors.primaryNavy))],
      ),
      body: Column(children: [
        _filters(tenants, rents.value ?? const []),
        const Divider(height: 1),
        Expanded(child: RefreshIndicator(
          onRefresh: () async { ref.invalidate(managerRentChargesProvider); ref.invalidate(managerTenantsProvider); },
          child: rents.when(
            loading: () => ListView.builder(padding: const EdgeInsets.all(16), itemCount: 4, itemBuilder: (_, __) => const SkeletonCard()),
            error: (error, _) => ListView(children: [SizedBox(height: 420, child: Center(child: Text('Could not load rent months: $error')))]),
            data: (items) => _rentList(items, tenants),
          ),
        )),
      ]),
    );
  }

  Widget _filters(List<UserProfile> tenants, List<Charge> charges) {
    final years = charges.map((c) => c.dueDate.year.toString()).toSet().toList()..sort();
    return Container(color: Colors.white, padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(LucideIcons.slidersHorizontal, size: 16, color: AppColors.primaryNavy), SizedBox(width: 8), Text('Filter by', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy))]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _dropdown(value: _year, label: 'Year', items: ['All', ...years], names: const {'All': 'All years'}, onChanged: (v) => setState(() => _year = v!))),
        const SizedBox(width: 10),
        Expanded(child: _dropdown(value: _resident, label: 'Tenant', items: ['All', ...tenants.map((t) => t.id)], names: {'All': 'All tenants', for (final t in tenants) t.id: t.fullName}, onChanged: (v) => setState(() => _resident = v!))),
      ]),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _scopeChip('Current & Upcoming', 'current_upcoming', LucideIcons.calendarCheck),
            const SizedBox(width: 8),
            _scopeChip('All Months', 'all', LucideIcons.calendarDays),
            const SizedBox(width: 8),
            _scopeChip('Unpaid / Due', 'unpaid', LucideIcons.alertCircle),
          ],
        ),
      ),
    ]));
  }

  Widget _scopeChip(String title, String value, IconData icon) {
    final selected = _viewScope == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: selected ? Colors.white : AppColors.primaryNavy),
      label: Text(title),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? Colors.white : AppColors.primaryNavy,
      ),
      selected: selected,
      selectedColor: AppColors.primaryNavy,
      backgroundColor: AppColors.lightBlue,
      showCheckmark: false,
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _viewScope = value;
            _showAllForResident.clear();
          });
        }
      },
    );
  }

  Widget _dropdown({required String value, required String label, required List<String> items, required Map<String, String> names, required ValueChanged<String?> onChanged}) => DropdownButtonFormField<String>(
    initialValue: items.contains(value) ? value : 'All', isExpanded: true,
    decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
    items: items.map((item) => DropdownMenuItem(value: item, child: Text(names[item] ?? item, overflow: TextOverflow.ellipsis))).toList(), onChanged: onChanged,
  );

  Widget _rentList(List<Charge> all, List<UserProfile> tenants) {
    final filtered = all.where((c) => (_resident == 'All' || c.residentId == _resident) && (_year == 'All' || c.dueDate.year.toString() == _year)).toList();
    final byTenant = <String, List<Charge>>{};
    for (final charge in filtered) { byTenant.putIfAbsent(charge.residentId, () => []).add(charge); }
    if (byTenant.isEmpty) {
      return ListView(
        children: const [
          SizedBox(
            height: 420,
            child: EmptyState(
              icon: LucideIcons.calendarX,
              title: 'No rent months found',
              description: 'Create a lease first or change the selected filters.',
            ),
          ),
        ],
      );
    }
    final ids = byTenant.keys.toList();
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: ids.length, itemBuilder: (_, index) {
      final id = ids[index];
      final months = byTenant[id]!..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final tenant = tenants.where((t) => t.id == id).firstOrNull;
      final first = months.first;
      final paid = months.where((c) => c.status == 'paid').length;

      final showAll = _viewScope == 'all' || _showAllForResident.contains(id);
      List<Charge> visibleMonths;
      if (showAll) {
        visibleMonths = months;
      } else if (_viewScope == 'unpaid') {
        visibleMonths = months.where((c) => c.status != 'paid').toList();
      } else {
        // 'current_upcoming'
        final now = DateTime.now();
        final currentMonthStart = DateTime(now.year, now.month, 1);
        final nextMonthLimit = DateTime(now.year, now.month + 2, 1);
        visibleMonths = months.where((c) {
          // Keep if overdue and unpaid
          if (c.dueDate.isBefore(currentMonthStart) && c.status != 'paid') return true;
          // Keep if current month
          if (c.dueDate.year == now.year && c.dueDate.month == now.month) return true;
          // Keep if next upcoming month
          if (c.dueDate.isAfter(currentMonthStart) && c.dueDate.isBefore(nextMonthLimit)) return true;
          return false;
        }).toList();

        if (visibleMonths.isEmpty && months.isNotEmpty) {
          final firstUnpaid = months.where((c) => c.status != 'paid').firstOrNull;
          visibleMonths = [firstUnpaid ?? months.first];
        }
      }

      final hiddenCount = months.length - visibleMonths.length;

      return Card(margin: const EdgeInsets.only(bottom: 14), child: Column(children: [
        InkWell(borderRadius: BorderRadius.circular(12), onTap: () => setState(() => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id)), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          _tenantAvatar(tenant),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tenant?.fullName ?? id, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4), Text(tenant?.unitNumber ?? 'No unit', style: AppTextStyles.bodySmall), const SizedBox(height: 4),
            Text('${_date(first.leaseStartDate ?? months.first.dueDate)} – ${_date(first.leaseEndDate ?? months.last.dueDate)}  •  $paid/${months.length} paid', style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText)),
          ])),
          if (first.leaseId.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.moreVertical, size: 20, color: AppColors.secondaryText),
              tooltip: 'Lease options',
              onSelected: (val) {
                if (val == 'renew_lease') {
                  _showRenewLeaseDialog(tenant, first, months);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'renew_lease',
                  child: Row(
                    children: [
                      Icon(LucideIcons.calendarPlus, size: 16, color: AppColors.primaryNavy),
                      SizedBox(width: 8),
                      Text('Renew / Extend Lease (+1 Year)'),
                    ],
                  ),
                ),
              ],
            ),
          Icon(_expanded.contains(id) ? LucideIcons.chevronUp : LucideIcons.chevronDown),
        ]))),
        if (_expanded.contains(id)) ...[
          const Divider(height: 1),
          for (final month in visibleMonths) _monthRow(month),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _showAllForResident.add(id)),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.calendarDays, size: 15, color: AppColors.primaryNavy),
                      const SizedBox(width: 8),
                      Text(
                        'Show all ${months.length} months ($hiddenCount hidden)',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_showAllForResident.contains(id) && _viewScope == 'current_upcoming')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAllForResident.remove(id)),
                  icon: const Icon(LucideIcons.eyeOff, size: 14),
                  label: const Text('Show current & upcoming only', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
        ],
      ]));
    });
  }

  Widget _monthRow(Charge charge) {
    final paid = charge.status == 'paid';
    final submitted = charge.status == 'payment_submitted';
    final hasLateFee = charge.lateFee > 0;
    final totalAmount = charge.amount + charge.lateFee;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Icon(
            paid
                ? LucideIcons.checkCircle2
                : submitted
                    ? LucideIcons.clock
                    : LucideIcons.calendar,
            color: paid
                ? AppColors.success
                : submitted
                    ? AppColors.warning
                    : AppColors.secondaryText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _month(charge.dueDate),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '\$${charge.amount.toStringAsFixed(2)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasLateFee)
                      GestureDetector(
                        onTap: () => _showLateFeeDialog(charge),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade300, width: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.alertCircle, size: 11, color: Colors.amber.shade900),
                              const SizedBox(width: 3),
                              Text(
                                '+ \$${charge.lateFee.toStringAsFixed(2)} Late Fee (Total: \$${totalAmount.toStringAsFixed(2)})',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (submitted)
                      Text(
                        ' • receipt submitted',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (paid) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Paid',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.undo2, size: 18, color: AppColors.error),
              tooltip: 'Cancel payment (Mark as unpaid)',
              onPressed: _saving.contains(charge.id) ? null : () => _cancelPaid(charge),
            ),
          ] else ...[
            FilledButton(
              onPressed: _saving.contains(charge.id) ? null : () => _confirmPaid(charge),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: AppColors.primaryNavy,
              ),
              child: Text(_saving.contains(charge.id) ? 'Saving…' : 'Confirm paid'),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreVertical, size: 18, color: AppColors.secondaryText),
            tooltip: 'Options',
            onSelected: (val) {
              if (val == 'late_fee') {
                _showLateFeeDialog(charge);
              } else if (val == 'remove_late_fee') {
                _removeLateFee(charge);
              } else if (val == 'cancel_paid') {
                _cancelPaid(charge);
              } else if (val == 'confirm_paid') {
                _confirmPaid(charge);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'late_fee',
                child: Row(
                  children: [
                    Icon(
                      hasLateFee ? LucideIcons.edit : LucideIcons.plusCircle,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Text(hasLateFee ? 'Edit Late Fee' : 'Add Late Fee'),
                  ],
                ),
              ),
              if (hasLateFee)
                const PopupMenuItem(
                  value: 'remove_late_fee',
                  child: Row(
                    children: [
                      Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Remove Late Fee', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              if (paid)
                const PopupMenuItem(
                  value: 'cancel_paid',
                  child: Row(
                    children: [
                      Icon(LucideIcons.undo2, size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Cancel Payment (Mark Unpaid)', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'confirm_paid',
                  child: Row(
                    children: [
                      Icon(LucideIcons.checkCircle2, size: 16, color: AppColors.success),
                      SizedBox(width: 8),
                      Text('Confirm Paid', style: TextStyle(color: AppColors.success)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tenantAvatar(UserProfile? tenant) {
    final avatarUrl = tenant?.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final initial = (tenant?.fullName.isNotEmpty ?? false)
        ? tenant!.fullName[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.lightBlue,
      foregroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      onForegroundImageError: hasAvatar ? (_, __) {} : null,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primaryNavy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _confirmPaid(Charge charge) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Confirm rent payment'), content: Text('Mark ${_month(charge.dueDate)} as paid? The tenant will see it as paid immediately.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm paid'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _saving.add(charge.id));
    try {
      await ref.read(paymentServiceProvider).confirmRentMonthPaid(charge);
      ref.invalidate(managerRentChargesProvider); ref.invalidate(chargesProvider); ref.invalidate(paymentsHistoryProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_month(charge.dueDate)} marked as paid.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not confirm payment: $error')));
    } finally { if (mounted) setState(() => _saving.remove(charge.id)); }
  }

  Future<void> _cancelPaid(Charge charge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Cancel rent payment'),
          ],
        ),
        content: Text(
          'Cancel payment for ${_month(charge.dueDate)}? This month will be reverted to unpaid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Paid'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Payment (Mark Unpaid)'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving.add(charge.id));
    try {
      await ref.read(paymentServiceProvider).cancelRentMonthPaid(charge);
      ref.invalidate(managerRentChargesProvider);
      ref.invalidate(chargesProvider);
      ref.invalidate(paymentsHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_month(charge.dueDate)} payment cancelled (marked unpaid).'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not cancel payment: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(charge.id));
    }
  }

  Future<void> _showLateFeeDialog(Charge charge) async {
    final controller = TextEditingController(
      text: charge.lateFee > 0 ? charge.lateFee.toStringAsFixed(2) : '50.00',
    );
    bool notifyTenant = true;

    final confirmed = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final feeVal = double.tryParse(controller.text.trim()) ?? 0.0;
          final totalVal = charge.amount + feeVal;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(LucideIcons.alertCircle, color: AppColors.warning, size: 22),
                const SizedBox(width: 8),
                Text(charge.lateFee > 0 ? 'Edit Late Fee' : 'Add Late Fee'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_month(charge.dueDate)} Rent',
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Base rent: \$${charge.amount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Late Fee Amount (\$) / مبلغ التأخير',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total with Late Fee:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          '\$${totalVal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Send notification to tenant', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('إشعار المستأجر بالمبلغ فوراً', style: TextStyle(fontSize: 11)),
                    value: notifyTenant,
                    onChanged: (val) => setDialogState(() => notifyTenant = val ?? true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              if (charge.lateFee > 0)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: () => Navigator.pop(context, 0.0),
                  child: const Text('Remove Fee'),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primaryNavy),
                icon: const Icon(LucideIcons.send, size: 16),
                onPressed: () {
                  final fee = double.tryParse(controller.text.trim());
                  if (fee != null && fee >= 0) {
                    Navigator.pop(context, fee);
                  }
                },
                label: const Text('Apply & Send'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == null || !mounted) return;

    setState(() => _saving.add(charge.id));
    try {
      await ref.read(paymentServiceProvider).updateLateFee(
        charge.id,
        confirmed,
        residentId: charge.residentId,
        monthTitle: '${_month(charge.dueDate)} Rent',
        baseAmount: charge.amount,
        notifyResident: notifyTenant,
      );
      ref.invalidate(managerRentChargesProvider);
      ref.invalidate(chargesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              confirmed > 0
                  ? 'Late fee of \$${confirmed.toStringAsFixed(2)} applied and sent to tenant.'
                  : 'Late fee removed from ${_month(charge.dueDate)}.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update late fee: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(charge.id));
    }
  }

  Future<void> _removeLateFee(Charge charge) async {
    setState(() => _saving.add(charge.id));
    try {
      await ref.read(paymentServiceProvider).updateLateFee(charge.id, 0.0);
      ref.invalidate(managerRentChargesProvider);
      ref.invalidate(chargesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Late fee removed from ${_month(charge.dueDate)}.'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not remove late fee: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(charge.id));
    }
  }

  Future<void> _showRenewLeaseDialog(UserProfile? tenant, Charge first, List<Charge> months) async {
    final currentEnd = first.leaseEndDate ?? months.last.dueDate;
    DateTime newEndDate = DateTime(currentEnd.year + 1, currentEnd.month, currentEnd.day);
    final rentController = TextEditingController(text: first.amount.toStringAsFixed(2));
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(LucideIcons.calendarPlus, color: AppColors.primaryNavy),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Renew / Extend Lease',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant?.fullName ?? 'Tenant',
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (tenant?.unitNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tenant!.unitNumber!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 16, color: AppColors.primaryNavy),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current Lease: ${_date(first.leaseStartDate ?? months.first.dueDate)} – ${_date(currentEnd)}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryNavy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('New Lease End Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: newEndDate,
                          firstDate: currentEnd,
                          lastDate: currentEnd.add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setDialogState(() => newEndDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendarCheck, size: 18, color: AppColors.primaryNavy),
                            const SizedBox(width: 10),
                            Text(
                              _date(newEndDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Spacer(),
                            const Text('Change', style: TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Monthly Rent (\$/month)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: rentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy, foregroundColor: Colors.white),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setDialogState(() => isSaving = true);
                          try {
                            final newRent = double.tryParse(rentController.text.trim());
                            await ref.read(paymentServiceProvider).extendLease(
                              leaseId: first.leaseId,
                              newEndDate: newEndDate,
                              newMonthlyRent: newRent,
                            );
                            ref.invalidate(managerRentChargesProvider);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Lease extended until ${_date(newEndDate)}! New 12 rent months generated automatically.',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Extend Lease (+1 Year)'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _month(DateTime date) => '${_months[date.month - 1]} ${date.year}';
  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
}
