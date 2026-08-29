import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/status_badge.dart';

class ManagerHomeScreen extends ConsumerWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).value;
    final requestsState = ref.watch(managerMaintenanceProvider);
    final paymentsState = ref.watch(managerPaymentsProvider);

    final tenantsState = ref.watch(managerTenantsProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        title: Text(
          localizations.translate('app_name'),
          style: TextStyle(
            color: context.primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              LucideIcons.settings,
              color: context.primaryTextColor,
              size: 20,
            ),
            tooltip: localizations.translate('settings'),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.logOut,
              color: context.isDarkMode
                  ? AppColors.lightBlue
                  : AppColors.primaryNavy,
              size: 20,
            ),
            tooltip: localizations.translate('log_out'),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(managerMaintenanceProvider);
            ref.invalidate(managerPaymentsProvider);
            ref.invalidate(managerTenantsProvider);
            ref.invalidate(managerPendingTenantsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // 1. Welcome Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.translate('manager_welcome'),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.lightBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.fullName ?? 'Property Owner',
                      style: AppTextStyles.heading2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      localizations.translate('manager_portal'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pending Approvals Alert Banner
              ref
                  .watch(managerPendingTenantsProvider)
                  .when(
                    data: (pending) {
                      if (pending.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          border: Border.all(color: AppColors.warning),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.userCheck,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.translate(
                                      'pending_registrations',
                                    ),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    localizations.translate(
                                      'awaiting_approval',
                                      pending.length.toString(),
                                    ),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  context.push('/manager/approvals'),
                              child: Text(
                                localizations.translate('review'),
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

              // 2. Metrics row
              _buildMetricsGrid(context, requestsState, paymentsState),
              const SizedBox(height: 24),

              // 3. Quick Actions Grid
              Text(
                localizations.translate('quick_actions'),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildActionCard(
                    context,
                    icon: LucideIcons.wrench,
                    title: localizations.translate('maintenance'),
                    subtitle: localizations.translate('history'),
                    color: AppColors.lightBlue,
                    iconColor: AppColors.primaryNavy,
                    onTap: () => context.push('/manager/maintenance'),
                  ),
                  _buildActionCard(
                    context,
                    icon: LucideIcons.creditCard,
                    title: localizations.translate('payments'),
                    subtitle: localizations.translate('receipt'),
                    color: AppColors.warningBg,
                    iconColor: AppColors.warning,
                    onTap: () => context.push('/manager/payments'),
                  ),
                  _buildActionCard(
                    context,
                    icon: LucideIcons.building,
                    title: localizations.translate('properties_units'),
                    subtitle: localizations.translate('manage_buildings'),
                    color: AppColors.successBg,
                    iconColor: AppColors.success,
                    onTap: () => context.push('/manager/properties'),
                  ),
                  _buildActionCard(
                    context,
                    icon: LucideIcons.userPlus,
                    title: localizations.translate('new_lease'),
                    subtitle: localizations.translate('assign_apartments'),
                    color: AppColors.lightBlue,
                    iconColor: AppColors.primaryNavy,
                    onTap: () => context.push('/manager/leases/create'),
                  ),
                  _buildActionCard(
                    context,
                    icon: LucideIcons.bellRing,
                    title: localizations.translate('notify_tenant'),
                    subtitle: localizations.translate('send_announcement'),
                    color: AppColors.warningBg,
                    iconColor: AppColors.warning,
                    onTap: () => context.push('/manager/notify'),
                  ),
                  _buildActionCard(
                    context,
                    icon: LucideIcons.userCheck,
                    title: localizations.translate('approvals'),
                    subtitle: ref
                        .watch(managerPendingTenantsProvider)
                        .when(
                          data: (list) => list.isEmpty
                              ? localizations.translate('no_pending')
                              : localizations.translate(
                                  'pending_count',
                                  list.length.toString(),
                                ),
                          loading: () =>
                              AppLocalizations.of(context).text('Loading...'),
                          error: (_, __) =>
                              AppLocalizations.of(context).text('Error'),
                        ),
                    color: AppColors.successBg,
                    iconColor: AppColors.success,
                    onTap: () => context.push('/manager/approvals'),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 4. Recent Maintenance Requests
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      localizations.translate('recent_maintenance_issues'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.push('/manager/maintenance'),
                    child: Text(
                      localizations.translate('view_all'),
                      style: const TextStyle(
                        color: AppColors.primaryNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              requestsState.when(
                data: (requests) {
                  final activeReqs = requests
                      .where(
                        (r) => r.status != 'closed' && r.status != 'cancelled',
                      )
                      .toList();
                  if (activeReqs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).text('No active maintenance issues found.'),
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }

                  final recent = activeReqs.take(3).toList();
                  return Column(
                    children: recent.map((req) {
                      return Card(
                        color: context.cardColor,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            req.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.primaryTextColor,
                            ),
                          ),
                          subtitle: Text(
                            'Unit: ${req.unitId.toUpperCase()} • ${req.category}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                          trailing: StatusBadge(status: req.status),
                          onTap: () =>
                              context.push('/manager/maintenance/${req.id}'),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryNavy,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    AppLocalizations.of(context).text('Error loading issues'),
                  ),
                ),
              ),

              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).text('APARTMENTS DIRECTORY'),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/manager/leases/create'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          AppLocalizations.of(context).text('+ Add Lease'),
                          style: TextStyle(
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => context.push('/manager/notify'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          AppLocalizations.of(context).text('Broadcast All'),
                          style: TextStyle(
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              tenantsState.when(
                data: (tenants) {
                  if (tenants.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).text('No registered tenants found.'),
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }

                  return Column(
                    children: tenants.map((tenant) {
                      return Card(
                        color: context.cardColor,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.lightBlue,
                            child: Text(
                              tenant.fullName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primaryNavy,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            tenant.fullName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.primaryTextColor,
                            ),
                          ),
                          subtitle: Text(
                            '${tenant.unitNumber ?? "No Unit"} • ${tenant.email}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.secondaryTextColor,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              LucideIcons.messageSquare,
                              color: AppColors.primaryNavy,
                              size: 20,
                            ),
                            tooltip: AppLocalizations.of(
                              context,
                            ).text('Send Direct Message'),
                            onPressed: () {
                              context.push(
                                '/manager/notify?tenantId=${tenant.id}',
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryNavy,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    ).text('Error loading tenants directory'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context,
    AsyncValue<List<dynamic>> requestsState,
    AsyncValue<List<dynamic>> paymentsState,
  ) {
    int activeIssues = 0;
    double rentCollected = 0.0;

    requestsState.whenData((reqs) {
      activeIssues = reqs
          .where((r) => r.status != 'closed' && r.status != 'cancelled')
          .length;
    });

    paymentsState.whenData((txns) {
      rentCollected = txns.fold(0.0, (sum, item) => sum + item.amount);
    });

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.activity,
                    color: AppColors.primaryNavy,
                    size: 20,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$activeIssues Active',
                    style: AppTextStyles.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context).text('Pending Repairs'),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.banknote,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${rentCollected.toStringAsFixed(0)}',
                    style: AppTextStyles.heading2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context).text('Total Revenue'),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      color: context.cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.isDarkMode ? color.withOpacity(0.15) : color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.primaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 10,
                  color: context.secondaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
