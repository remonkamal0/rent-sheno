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
    ]));
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
        children: [
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
      return Card(margin: const EdgeInsets.only(bottom: 14), child: Column(children: [
        InkWell(borderRadius: BorderRadius.circular(12), onTap: () => setState(() => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id)), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          _tenantAvatar(tenant),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tenant?.fullName ?? id, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4), Text(tenant?.unitNumber ?? 'No unit', style: AppTextStyles.bodySmall), const SizedBox(height: 4),
            Text('${_date(first.leaseStartDate ?? months.first.dueDate)} – ${_date(first.leaseEndDate ?? months.last.dueDate)}  •  $paid/${months.length} paid', style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText)),
          ])),
          Icon(_expanded.contains(id) ? LucideIcons.chevronUp : LucideIcons.chevronDown),
        ]))),
        if (_expanded.contains(id)) ...[const Divider(height: 1), for (final month in months) _monthRow(month)],
      ]));
    });
  }

  Widget _monthRow(Charge charge) {
    final paid = charge.status == 'paid';
    final submitted = charge.status == 'payment_submitted';
    return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 12, 12), child: Row(children: [
      Icon(paid ? LucideIcons.checkCircle2 : LucideIcons.calendar, color: paid ? AppColors.success : submitted ? AppColors.warning : AppColors.secondaryText),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_month(charge.dueDate), style: const TextStyle(fontWeight: FontWeight.w700)), Text('\$${charge.amount.toStringAsFixed(2)}${submitted ? ' • receipt submitted' : ''}', style: AppTextStyles.bodySmall)])),
      if (paid) const Chip(label: Text('Paid'), backgroundColor: AppColors.successBg, labelStyle: TextStyle(color: AppColors.success)) else FilledButton(
        onPressed: _saving.contains(charge.id) ? null : () => _confirmPaid(charge),
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)), child: Text(_saving.contains(charge.id) ? 'Saving…' : 'Confirm paid'),
      ),
    ]));
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
      foregroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
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

  String _month(DateTime date) => '${_months[date.month - 1]} ${date.year}';
  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
}
