import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/maintenance_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/app_image_viewer_dialog.dart';

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
        title: Text(localizations.text('Request {}', requestId)),
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
                title: AppLocalizations.of(context).text('Request Not Found'),
                description: AppLocalizations.of(
                  context,
                ).text('We couldn\'t find the requested maintenance details.'),
                preferredDate: DateTime.now(),
                status: 'cancelled',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                attachmentUrls: [],
              ),
            );

            if (request.title ==
                AppLocalizations.of(context).text('Request Not Found')) {
              return Center(child: Text(request.description));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories and Status Badges
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              request.category.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                          style: AppTextStyles.heading2.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 16),

                        // Date columns
                        _buildDetailRow(
                          icon: LucideIcons.calendar,
                          title: AppLocalizations.of(
                            context,
                          ).text('Submitted Date'),
                          value: DateFormatter.formatDateTime(
                            request.createdAt,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: LucideIcons.calendarRange,
                          title: AppLocalizations.of(
                            context,
                          ).text('Preferred Date'),
                          value: DateFormatter.formatShortDate(
                            request.preferredDate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: LucideIcons.user,
                          title: AppLocalizations.of(
                            context,
                          ).text('Assigned Tech'),
                          value: request.visitPerson ?? 'TBD',
                        ),
                        if (request.scheduledFor != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: .3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Maintenance visit confirmed',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  icon: LucideIcons.calendarClock,
                                  title: 'Date & Time',
                                  value:
                                      '${DateFormatter.formatShortDate(request.scheduledFor!)} ${TimeOfDay(hour: request.scheduledFor!.hour, minute: request.scheduledFor!.minute).format(context)}',
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _addToCalendar(
                                      context,
                                      request,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.calendarPlus,
                                      size: 18,
                                    ),
                                    label: const Text('Add to Phone Calendar'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).text('Issue Description').toUpperCase(),
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
                                final img = request.attachmentUrls[index];
                                return GestureDetector(
                                  onTap: () {
                                    AppImageViewerDialog.show(
                                      context,
                                      imageUrls: request.attachmentUrls,
                                      initialIndex: index,
                                    );
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: AppColors.border.withValues(alpha: 0.3),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            img,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const Center(
                                              child: Icon(
                                                LucideIcons.image,
                                                color: AppColors.secondaryText,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 16,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(
                                            LucideIcons.maximize2,
                                            color: Colors.white,
                                            size: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
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
                          style: AppTextStyles.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTimeline(context, request.status),
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
          error: (err, stack) =>
              Center(child: Text(localizations.translate('error_loading'))),
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
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addToCalendar(
    BuildContext context,
    MaintenanceRequest request,
  ) async {
    final start = request.scheduledFor;
    if (start == null) return;
    final end = start.add(const Duration(hours: 1));
    String calendarDate(DateTime value) => value
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[-:]'), '')
        .split('.').first
        .replaceFirst(RegExp(r'$'), 'Z');
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Maintenance visit - ${request.title}',
      'dates': '${calendarDate(start)}/${calendarDate(end)}',
      'details':
          '${request.visitPerson ?? 'Maintenance technician'} will visit to repair: ${request.description}',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the calendar app.')),
      );
    }
  }

  Widget _buildTimeline(BuildContext context, String status) {
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
          title: AppLocalizations.of(context).text('Request Submitted'),
          subtitle: AppLocalizations.of(
            context,
          ).text('We have received your request.'),
          isCompleted: step >= 1,
          isLast: false,
        ),
        _buildTimelineStep(
          title: AppLocalizations.of(context).text('Request Reviewed'),
          subtitle: AppLocalizations.of(
            context,
          ).text('Our management has verified the details.'),
          isCompleted: step >= 2,
          isLast: false,
        ),
        _buildTimelineStep(
          title: AppLocalizations.of(context).text('Technician Assigned'),
          subtitle: AppLocalizations.of(
            context,
          ).text('A qualified contractor has been selected.'),
          isCompleted: step >= 3,
          isLast: false,
        ),
        _buildTimelineStep(
          title: AppLocalizations.of(context).text('Completed'),
          subtitle: AppLocalizations.of(
            context,
          ).text('The issue has been resolved.'),
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
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
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
                      color: isCompleted
                          ? AppColors.primaryText
                          : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
