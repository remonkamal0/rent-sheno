import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/app_buttons.dart';

class ManagerDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const ManagerDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<ManagerDetailScreen> createState() => _ManagerDetailScreenState();
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
            content: Text('Request status updated to ${status.toUpperCase()}'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsState = ref.watch(managerMaintenanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Issue Ticket Details'),
      ),
      body: SafeArea(
        child: requestsState.when(
          data: (requests) {
            final reqList = requests.where((r) => r.id == widget.requestId);
            final req = reqList.isNotEmpty ? reqList.first : null;

            if (req == null) {
              return const Center(child: Text('Request ticket not found.'));
            }

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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              req.requestNumber,
                              style: AppTextStyles.label.copyWith(color: AppColors.secondaryText),
                            ),
                            StatusBadge(status: req.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          req.title,
                          style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Category: ${req.category.toUpperCase()}',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText, fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 32),
                        
                        _buildInfoRow('Apartment Unit', req.unitId.toUpperCase()),
                        const SizedBox(height: 12),
                        _buildInfoRow('Tenant ID', req.residentId),
                        const SizedBox(height: 12),
                        _buildInfoRow('Submitted Date', DateFormatter.formatRelative(req.createdAt)),
                        const SizedBox(height: 12),
                        _buildInfoRow('Preferred Visit', DateFormatter.formatRelative(req.preferredDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Issue Description
                Text('DESCRIPTION OF THE ISSUE', style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 11)),
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
                  Text('ATTACHED PHOTOS', style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 11)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: req.attachmentUrls.length,
                      itemBuilder: (context, index) {
                        final img = req.attachmentUrls[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.border.withOpacity(0.3),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Center(
                                child: Icon(LucideIcons.image, color: AppColors.secondaryText),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                // Action controls for owners
                if (req.status != 'closed' && req.status != 'cancelled') ...[
                  Text('TICKET ACTIONS', style: AppTextStyles.label.copyWith(color: AppColors.secondaryText, fontSize: 11)),
                  const SizedBox(height: 12),
                  
                  if (_isUpdating)
                    const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
                  else ...[
                    if (req.status == 'pending') ...[
                      AppPrimaryButton(
                        text: 'Mark In Progress',
                        onTap: () => _updateStatus('in_progress'),
                      ),
                      const SizedBox(height: 12),
                      AppSecondaryButton(
                        text: 'Schedule Repair',
                        onTap: () => _updateStatus('scheduled'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (req.status == 'in_progress' || req.status == 'scheduled') ...[
                      AppPrimaryButton(
                        text: 'Mark as Completed / Resolved',
                        onTap: () => _updateStatus('closed'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _updateStatus('cancelled'),
                      child: const Text('Cancel / Reject Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy)),
          error: (e, _) => const Center(child: Text('Error loading ticket')),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText)),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryText)),
      ],
    );
  }
}
