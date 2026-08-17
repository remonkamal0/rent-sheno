import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/maintenance_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/sms_app_bar.dart';
import '../../../core/widgets/sms_drawer.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/empty_state.dart';

class MaintenanceListScreen extends ConsumerStatefulWidget {
  const MaintenanceListScreen({super.key});

  @override
  ConsumerState<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends ConsumerState<MaintenanceListScreen> {
  int _activeTab = 0; // 0: History, 1: New Request (which navigates to the form)

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final requestsState = ref.watch(maintenanceRequestsProvider);

    return Scaffold(
      appBar: const SmsAppBar(),
      drawer: const SmsDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(maintenanceRequestsProvider),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Page Info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.translate('maintenance_center'),
                    style: AppTextStyles.heading1.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    localizations.translate('maintenance_desc'),
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  // New Request Primary CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/maintenance/new'),
                      icon: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
                      label: Text(
                        localizations.translate('new_request'),
                        style: AppTextStyles.button,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Custom Tabs Navigation
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
                      label: localizations.translate('history'),
                      isSelected: _activeTab == 0,
                      onTap: () {
                        setState(() {
                          _activeTab = 0;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildTabItem(
                      label: localizations.translate('new_request'),
                      isSelected: _activeTab == 1,
                      onTap: () {
                        context.push('/maintenance/new');
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Tab View Body (History List)
            Expanded(
              child: requestsState.when(
                data: (requests) {
                  if (requests.isEmpty) {
                    return EmptyState(
                      icon: LucideIcons.wrench,
                      title: 'No maintenance requests yet',
                      description: 'Report issues regarding plumbing, electrical, and other appliances.',
                      actionText: localizations.translate('new_request'),
                      onActionTap: () => context.push('/maintenance/new'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      return MaintenanceRequestCard(request: requests[index]);
                    },
                  );
                },
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 3,
                  itemBuilder: (context, index) => const SkeletonCard(),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(localizations.translate('error_loading')),
                  ),
                ),
              ),
            ),
          ],
        ),
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
}

class MaintenanceRequestCard extends StatelessWidget {
  final MaintenanceRequest request;

  const MaintenanceRequestCard({required this.request, super.key});

  @override
  Widget build(BuildContext context) {
    final bool isClosed = request.status == 'closed' || request.status == 'cancelled';
    final dateLabel = isClosed ? 'Resolved: ' : 'Submitted: ';
    final displayDate = isClosed 
        ? (request.resolvedAt ?? request.updatedAt) 
        : request.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => context.push('/maintenance/${request.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      request.title,
                      style: AppTextStyles.heading3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.secondaryText,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$dateLabel${DateFormatter.formatShortDate(displayDate)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
