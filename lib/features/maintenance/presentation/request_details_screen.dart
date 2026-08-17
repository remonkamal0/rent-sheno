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
import '../../../core/widgets/status_badge.dart';

class RequestDetailsScreen extends ConsumerWidget {
  final String requestId;

  const RequestDetailsScreen({required this.requestId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final requestsState = ref.watch(maintenanceRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Request $requestId'),
      ),
      body: SafeArea(
        child: requestsState.when(
          data: (requests) {
            // Find the request
            final request = requests.firstWhere(
              (r) => r.id == requestId || r.requestNumber == requestId,
              orElse: () => MaintenanceRequest(
                id: requestId,
                residentId: 'mock-user-123',
                unitId: 'unit-402',
                requestNumber: requestId,
                category: 'other',
                title: 'Request Not Found',
                description: 'We couldn\'t find the requested maintenance details.',
                preferredDate: DateTime.now(),
                status: 'cancelled',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                attachmentUrls: [],
              ),
            );

            if (request.title == 'Request Not Found') {
              return Center(
                child: Text(request.description),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories and Status Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          request.category.toUpperCase(),
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      StatusBadge(status: request.status),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title and details card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 16),

                        // Date columns
                        _buildDetailRow(
                          icon: LucideIcons.calendar,
                          title: 'Submitted Date',
                          value: DateFormatter.formatShortDate(request.createdAt),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: LucideIcons.calendarRange,
                          title: 'Preferred Date',
                          value: DateFormatter.formatShortDate(request.preferredDate),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: LucideIcons.user,
                          title: 'Assigned Tech',
                          value: request.assignedTo ?? 'TBD',
                        ),
                        
                        const SizedBox(height: 20),
                        Text(
                          'Issue Description'.toUpperCase(),
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.secondaryText,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          request.description,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primaryText,
                            height: 1.4,
                          ),
                        ),

                        // Attachment preview
                        if (request.attachmentUrls.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Attached Images'.toUpperCase(),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: request.attachmentUrls.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    _showFullScreenImage(context, request.attachmentUrls[index]);
                                  },
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(request.attachmentUrls[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Timeline Tracker Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.translate('timeline'),
                          style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        _buildTimeline(request.status),
                      ],
                    ),
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
          error: (err, stack) => Center(
            child: Text(localizations.translate('error_loading')),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryText),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(String status) {
    // pending, in_progress, scheduled, closed, cancelled
    final int step;
    switch (status.trim().toLowerCase()) {
      case 'pending':
        step = 1;
        break;
      case 'in_progress':
      case 'in progress':
        step = 2;
        break;
      case 'scheduled':
        step = 3;
        break;
      case 'closed':
        step = 4;
        break;
      default:
        step = 1;
    }

    return Column(
      children: [
        _buildTimelineStep(
          title: 'Request Submitted',
          subtitle: 'We have received your request.',
          isCompleted: step >= 1,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Request Reviewed',
          subtitle: 'Our management has verified the details.',
          isCompleted: step >= 2,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Technician Assigned',
          subtitle: 'A qualified contractor has been selected.',
          isCompleted: step >= 3,
          isLast: false,
        ),
        _buildTimelineStep(
          title: 'Completed',
          subtitle: 'The issue has been resolved.',
          isCompleted: step >= 4,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : Colors.white,
                  border: Border.all(
                    color: isCompleted ? AppColors.success : AppColors.border,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: VerticalDivider(
                    color: isCompleted ? AppColors.success : AppColors.border,
                    thickness: 2,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? AppColors.primaryText : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
