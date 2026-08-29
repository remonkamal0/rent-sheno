import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/sms_back_button.dart';
import '../../../core/widgets/empty_state.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter =
      'all'; // all, unread, maintenance, payment, insurance, general

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final notificationsState = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const SmsBackButton(),
        title: Text(localizations.translate('notifications_center')),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationsProvider.notifier).readAll(),
            child: Text(
              localizations.translate('mark_all_read'),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Horizontal Chips List
            Container(
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                children: [
                  _buildFilterChip(
                    id: 'all',
                    label: localizations.translate('all'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    id: 'unread',
                    label: localizations.translate('unread'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    id: 'maintenance',
                    label: localizations.translate('maintenance'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    id: 'payment',
                    label: localizations.translate('payments'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    id: 'insurance',
                    label: AppLocalizations.of(context).text('Insurance'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    id: 'general',
                    label: localizations.translate('general'),
                  ),
                ],
              ),
            ),

            // List of Notifications
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: notificationsState.when(
                  data: (notifications) {
                    // Filter notifications
                    List<AppNotification> filteredList = [];
                    if (_selectedFilter == 'all') {
                      filteredList = notifications;
                    } else if (_selectedFilter == 'unread') {
                      filteredList = notifications
                          .where((n) => !n.isRead)
                          .toList();
                    } else {
                      filteredList = notifications
                          .where((n) => n.type == _selectedFilter)
                          .toList();
                    }

                    if (filteredList.isEmpty) {
                      return EmptyState(
                        icon: LucideIcons.bellOff,
                        title: AppLocalizations.of(
                          context,
                        ).text('No notifications found'),
                        description: AppLocalizations.of(context).text(
                          'You\'re all caught up! There are no announcements or alerts in this category.',
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final notification = filteredList[index];
                        return _buildNotificationCard(context, notification);
                      },
                    );
                  },
                  loading: () => ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 4,
                    itemBuilder: (context, index) => const SkeletonCard(),
                  ),
                  error: (err, stack) => Center(
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

  Widget _buildFilterChip({required String id, required String label}) {
    final isSelected = _selectedFilter == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryNavy
              : AppColors.lightBlue.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: isSelected ? Colors.white : AppColors.secondaryText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotification notification,
  ) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (notification.type) {
      case 'maintenance':
        icon = LucideIcons.wrench;
        iconColor = AppColors.primaryNavy;
        bgColor = AppColors.lightBlue;
        break;
      case 'payment':
        icon = LucideIcons.creditCard;
        iconColor = AppColors.warning;
        bgColor = AppColors.warningBg;
        break;
      case 'insurance':
        icon = LucideIcons.shield;
        iconColor = AppColors.success;
        bgColor = AppColors.successBg;
        break;
      default: // general
        icon = notification.title.toLowerCase().contains('alarm')
            ? LucideIcons.megaphone
            : LucideIcons.droplets;
        iconColor = AppColors.primaryNavy;
        bgColor = AppColors.lightBlue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead
          ? Colors.white
          : AppColors.lightBlue.withOpacity(0.15),
      child: InkWell(
        onTap: () {
          ref.read(notificationsProvider.notifier).readSingle(notification.id);

          if (notification.type == 'maintenance') {
            context.go('/maintenance');
          } else if (notification.type == 'payment') {
            context.go('/payments');
          } else if (notification.type == 'insurance') {
            context.go('/insurance');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.bold
                                  : FontWeight.w900,
                              color: AppColors.primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormatter.formatRelative(
                            notification.createdAt,
                            AppLocalizations.of(context),
                          ),
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
