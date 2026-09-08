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
import '../../../core/widgets/sms_app_bar.dart';
import '../../../core/widgets/sms_drawer.dart';
import '../../../core/widgets/skeleton_loading.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final residenceState = ref.watch(residenceDetailsProvider);
    final chargesState = ref.watch(chargesProvider);
    final notificationsState = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: const SmsAppBar(),
      drawer: const SmsDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(residenceDetailsProvider);
          ref.read(chargesProvider.notifier).refresh();
          ref.invalidate(notificationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. Residence Card
            residenceState.when(
              data: (residence) {
                if (residence == null) return const SizedBox.shrink();
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CachedImageBanner(
                        imageUrl:
                            residence.property.imageUrl ??
                            'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&q=80&w=600',
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current Residence Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.mapPin,
                                    size: 12,
                                    color: AppColors.primaryNavy,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    localizations.translate(
                                      'current_residence',
                                    ),
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.primaryNavy,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              residence.property.addressLine1,
                              style: AppTextStyles.display.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              residence.unit.unitNumber,
                              style: AppTextStyles.heading3.copyWith(
                                color: AppColors.secondaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SkeletonResidenceCard(),
              error: (err, stack) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(localizations.translate('error_loading')),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Maintenance Quick Action (Navy Card)
            GestureDetector(
              onTap: () => context.go('/maintenance'),
              child: Card(
                color: AppColors.darkNavy,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Circular wrench icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.wrench,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.translate('maintenance_request'),
                              style: AppTextStyles.heading3.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              localizations.translate(
                                'maintenance_request_desc',
                              ),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.lightBlue.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Upcoming / Current Balance Card
            chargesState.when(
              data: (charges) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                // Outstanding charges (not paid)
                final outstanding = charges
                    .where((c) => c.status != 'paid')
                    .toList()
                  ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

                // 1. Unpaid charges due in current month or prior
                final currentAndPastUnpaid = outstanding.where((c) {
                  final due = DateTime(c.dueDate.year, c.dueDate.month, c.dueDate.day);
                  final isPriorOrCurrentMonth = c.dueDate.year < now.year ||
                      (c.dueDate.year == now.year && c.dueDate.month <= now.month);
                  return isPriorOrCurrentMonth || due.isBefore(today) || due.isAtSameMomentAs(today);
                }).toList();

                // 2. Future upcoming charges (next month and beyond)
                final futureCharges = outstanding.where((c) {
                  return !currentAndPastUnpaid.contains(c);
                }).toList();

                final nextUpcomingCharge = futureCharges.isNotEmpty ? futureCharges.first : null;

                // Case A: Tenant owes money for current or past months
                if (currentAndPastUnpaid.isNotEmpty) {
                  final activeCharge = currentAndPastUnpaid.first;
                  final totalDue = currentAndPastUnpaid.fold<double>(
                    0.0,
                    (sum, item) => sum + item.totalAmount,
                  );
                  final isPastDue = currentAndPastUnpaid.any((c) => c.calculatedStatus == 'past_due');
                  final daysText = DateFormatter.formatOverdueDate(
                    activeCharge.dueDate,
                    localizations,
                  );

                  return GestureDetector(
                    onTap: () => context.go('/payments'),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: AppColors.lightBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.creditCard,
                                    color: AppColors.primaryNavy,
                                    size: 24,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPastDue ? AppColors.errorBg : AppColors.warningBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    daysText.toUpperCase(),
                                    style: AppTextStyles.label.copyWith(
                                      color: isPastDue ? AppColors.error : AppColors.warning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isPastDue
                                  ? (localizations.locale.languageCode == 'ar' ? 'رصيد متأخر' : 'Past Due Balance')
                                  : localizations.translate('current_balance'),
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${totalDue.toStringAsFixed(2)}',
                              style: AppTextStyles.display.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isPastDue ? AppColors.error : AppColors.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Case B: Current month is paid!
                // Only show upcoming month's balance on or after the 27th of the month.
                // Before the 27th, show Current Balance: $0.00 (All caught up).
                final showUpcoming = now.day >= 27 && nextUpcomingCharge != null;

                if (showUpcoming) {
                  final daysText = DateFormatter.formatOverdueDate(
                    nextUpcomingCharge.dueDate,
                    localizations,
                  );

                  return GestureDetector(
                    onTap: () => context.go('/payments'),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: AppColors.lightBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.creditCard,
                                    color: AppColors.primaryNavy,
                                    size: 24,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    daysText.toUpperCase(),
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.warning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              localizations.translate('upcoming_balance'),
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${nextUpcomingCharge.totalAmount.toStringAsFixed(2)}',
                              style: AppTextStyles.display.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Case C: Current month paid & before 27th of the month -> $0.00 Current Balance
                return GestureDetector(
                  onTap: () => context.go('/payments'),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.successBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.check,
                              color: AppColors.success,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations.translate('current_balance'),
                                  style: AppTextStyles.bodyMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\$0.00',
                                  style: AppTextStyles.heading2.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (nextUpcomingCharge != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    localizations.locale.languageCode == 'ar'
                                        ? 'الإيجار القادم: \$${nextUpcomingCharge.totalAmount.toStringAsFixed(2)} مستحق في ${DateFormatter.formatShortDate(nextUpcomingCharge.dueDate)}'
                                        : 'Next: \$${nextUpcomingCharge.totalAmount.toStringAsFixed(2)} due on ${DateFormatter.formatShortDate(nextUpcomingCharge.dueDate)}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.secondaryText,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () =>
                  const SkeletonContainer(width: double.infinity, height: 110),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // 4. Recent Notifications Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    localizations.translate('recent_notifications'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () =>
                      ref.read(notificationsProvider.notifier).readAll(),
                  child: Text(
                    localizations.translate('mark_all_read'),
                    maxLines: 1,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notifications List (Max 2)
            notificationsState.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).text('No notifications yet.'),
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  );
                }

                final recentList = list.take(2).toList();
                return Column(
                  children: recentList.map((notify) {
                    return HomeNotificationCard(notification: notify);
                  }).toList(),
                );
              },
              loading: () => Column(
                children: const [
                  SkeletonContainer(width: double.infinity, height: 75),
                  SizedBox(height: 8),
                  SkeletonContainer(width: double.infinity, height: 75),
                ],
              ),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class CachedImageBanner extends StatelessWidget {
  final String imageUrl;

  const CachedImageBanner({required this.imageUrl, super.key});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      height: 180,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 180,
          color: AppColors.border.withOpacity(0.3),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryNavy),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 180,
          color: AppColors.border.withOpacity(0.3),
          child: const Icon(
            LucideIcons.image,
            color: AppColors.secondaryText,
            size: 40,
          ),
        );
      },
    );
  }
}

class HomeNotificationCard extends ConsumerWidget {
  final AppNotification notification;

  const HomeNotificationCard({required this.notification, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
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
      child: InkWell(
        onTap: () {
          ref.read(notificationsProvider.notifier).readSingle(notification.id);
          // Navigate to respective page depending on notification type
          if (notification.type == 'maintenance') {
            context.go('/maintenance');
          } else if (notification.type == 'payment') {
            context.go('/payments');
          } else if (notification.type == 'insurance') {
            context.go('/insurance');
          } else {
            context.push('/notifications');
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
                              fontWeight: FontWeight.bold,
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
                            localizations,
                          ),
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.secondaryText,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
