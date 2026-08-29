import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/sms_back_button.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/empty_state.dart';

class ManagerMaintenanceScreen extends ConsumerStatefulWidget {
  const ManagerMaintenanceScreen({super.key});

  @override
  ConsumerState<ManagerMaintenanceScreen> createState() =>
      _ManagerMaintenanceScreenState();
}

class _ManagerMaintenanceScreenState
    extends ConsumerState<ManagerMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final requestsState = ref.watch(managerMaintenanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const SmsBackButton(),
        title: Text(localizations.translate('maintenance_management')),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryNavy,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primaryNavy,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: AppLocalizations.of(context).text('Active Issues')),
            Tab(text: AppLocalizations.of(context).text('Closed / History')),
          ],
        ),
      ),
      body: SafeArea(
        child: requestsState.when(
          data: (requests) {
            final activeRequests = requests
                .where((r) => r.status != 'closed' && r.status != 'cancelled')
                .toList();
            final closedRequests = requests
                .where((r) => r.status == 'closed' || r.status == 'cancelled')
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList(
                  context,
                  activeRequests,
                  AppLocalizations.of(context).text(
                    'No active maintenance issues! All systems running smoothly.',
                  ),
                ),
                _buildRequestsList(
                  context,
                  closedRequests,
                  AppLocalizations.of(
                    context,
                  ).text('No maintenance history records found.'),
                ),
              ],
            );
          },
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: 4,
            itemBuilder: (context, index) => const SkeletonCard(),
          ),
          error: (err, _) =>
              Center(child: Text(localizations.translate('error_loading'))),
        ),
      ),
    );
  }

  Widget _buildRequestsList(
    BuildContext context,
    List<dynamic> list,
    String emptyMsg,
  ) {
    if (list.isEmpty) {
      return EmptyState(
        icon: LucideIcons.wrench,
        title: AppLocalizations.of(context).text('All Clear'),
        description: emptyMsg,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final req = list[index];
        IconData categoryIcon;
        switch (req.category) {
          case 'plumbing':
            categoryIcon = LucideIcons.droplet;
            break;
          case 'electrical':
            categoryIcon = LucideIcons.zap;
            break;
          case 'appliance':
            categoryIcon = LucideIcons.tv;
            break;
          default:
            categoryIcon = LucideIcons.helpCircle;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () async {
              await context.push('/manager/maintenance/${req.id}');
              // Refresh requests when coming back
              ref.invalidate(managerMaintenanceProvider);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      categoryIcon,
                      color: AppColors.primaryNavy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Unit ${req.unitId.toUpperCase()} • ${req.requestNumber}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: req.status),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
