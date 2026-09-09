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
import '../../../core/widgets/sms_back_button.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_image_viewer_dialog.dart';

class ManagerDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const ManagerDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<ManagerDetailScreen> createState() =>
      _ManagerDetailScreenState();
}

class _ManagerDetailScreenState extends ConsumerState<ManagerDetailScreen> {
  bool _isUpdating = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _isUpdating = true);
    try {
      final maintenanceService = ref.read(maintenanceServiceProvider);
      await maintenanceService.updateRequestStatus(widget.requestId, status);

      if (mounted) {
        ref.invalidate(managerMaintenanceProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).text('Request status updated to {}', status.toUpperCase()),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).text('Error: {}', e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _scheduleRepair(MaintenanceRequest request) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    var visitPerson = 'Maintenance technician';
    final confirmedPerson = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Who will attend?'),
        content: TextFormField(
          initialValue: visitPerson,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name or role',
            hintText: 'e.g. Ahmed / Plumbing technician',
          ),
          onChanged: (value) => visitPerson = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (visitPerson.trim().isNotEmpty) {
                Navigator.pop(dialogContext, visitPerson.trim());
              }
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
    if (confirmedPerson == null || !mounted) return;

    final scheduledFor = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final formattedDate = DateFormatter.formatShortDate(scheduledFor);
    final formattedTime = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time);

    setState(() => _isUpdating = true);
    try {
      await ref.read(maintenanceServiceProvider).scheduleVisit(
        requestId: request.id,
        scheduledFor: scheduledFor,
        visitPerson: confirmedPerson,
      );
      await ref.read(notificationServiceProvider).sendNotification(
        residentId: request.residentId,
        title: 'Maintenance visit scheduled',
        message:
            '$confirmedPerson will visit on $formattedDate at $formattedTime for: ${request.title}.',
        type: 'maintenance',
      );
      ref.invalidate(managerMaintenanceProvider);
      ref.invalidate(notificationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit scheduled and tenant notified.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not schedule visit: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsState = ref.watch(managerMaintenanceProvider);
    final tenantsState = ref.watch(managerTenantsProvider);
    final unitsState = ref.watch(managerUnitsProvider);
    final localizations = AppLocalizations.of(context);
    final tenantsList = tenantsState.value ?? [];
    final unitsList = unitsState.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const SmsBackButton(),
        title: Text(localizations.translate('issue_ticket_details')),
      ),
      body: SafeArea(
        child: requestsState.when(
          data: (requests) {
            final reqList = requests.where((r) => r.id == widget.requestId);
            final req = reqList.isNotEmpty ? reqList.first : null;

            if (req == null) {
              return Center(
                child: Text(
                  AppLocalizations.of(
                    context,
                  ).text('Request ticket not found.'),
                ),
              );
            }

            final matchingTenant = tenantsList
                .where((t) => t.id == req.residentId)
                .firstOrNull;
            final matchingUnit = unitsList
                .where((u) => u.id == req.unitId)
                .firstOrNull;
            final unitText = req.unitNumber ??
                matchingUnit?.unitNumber ??
                matchingTenant?.unitNumber ??
                'Unit';
            final residentText = req.residentName ??
                matchingTenant?.fullName ??
                'Resident';

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Ticket header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                req.requestNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            StatusBadge(status: req.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          req.title,
                          style: AppTextStyles.heading2.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).text('Category: {}', req.category.toUpperCase()),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 32),

                        _buildInfoRow(
                          AppLocalizations.of(context).text('Apartment Unit'),
                          unitText,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          AppLocalizations.of(context).text('Tenant Name'),
                          residentText,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          AppLocalizations.of(context).text('Submitted Date'),
                          DateFormatter.formatDateTime(req.createdAt),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          AppLocalizations.of(context).text('Preferred Visit'),
                          DateFormatter.formatShortDate(req.preferredDate),
                        ),
                        if (req.scheduledFor != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Scheduled Visit',
                            '${DateFormatter.formatShortDate(req.scheduledFor!)} ${TimeOfDay(hour: req.scheduledFor!.hour, minute: req.scheduledFor!.minute).format(context)}',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Coming To Repair',
                            req.visitPerson ?? 'Maintenance technician',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Issue Description
                Text(
                  localizations.translate('description_of_issue'),
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      req.description,
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Attached Images
                if (req.attachmentUrls.isNotEmpty) ...[
                  Text(
                    localizations.translate('attached_photos'),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: req.attachmentUrls.length,
                      itemBuilder: (context, index) {
                        final img = req.attachmentUrls[index];
                        return GestureDetector(
                          onTap: () {
                            AppImageViewerDialog.show(
                              context,
                              imageUrls: req.attachmentUrls,
                              initialIndex: index,
                            );
                          },
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 120,
                                height: 120,
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
                                right: 18,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    LucideIcons.maximize2,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // Action controls for owners
                if (req.status != 'closed' && req.status != 'cancelled') ...[
                  Text(
                    localizations.translate('ticket_actions'),
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isUpdating)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryNavy,
                      ),
                    )
                  else ...[
                    if (req.status == 'pending') ...[
                      AppPrimaryButton(
                        text: AppLocalizations.of(
                          context,
                        ).text('Mark In Progress'),
                        onTap: () => _updateStatus('in_progress'),
                      ),
                      const SizedBox(height: 12),
                      AppSecondaryButton(
                        text: AppLocalizations.of(
                          context,
                        ).text('Schedule Repair'),
                        onTap: () => _scheduleRepair(req),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (req.status == 'in_progress' ||
                        req.status == 'scheduled') ...[
                      AppPrimaryButton(
                        text: AppLocalizations.of(
                          context,
                        ).text('Mark as Completed / Resolved'),
                        onTap: () => _updateStatus('closed'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _updateStatus('cancelled'),
                      child: Text(
                        localizations.translate('cancel_reject_ticket'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryNavy),
          ),
          error: (e, _) => Center(
            child: Text(
              AppLocalizations.of(context).text('Error loading ticket'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}
