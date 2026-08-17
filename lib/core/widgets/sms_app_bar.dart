import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../services/providers.dart';

class SmsAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final bool showLeading;

  const SmsAppBar({this.title, this.showLeading = true, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationsProvider);
    
    // Calculate unread notifications count
    final int unreadCount = notificationsState.value
            ?.where((n) => !n.isRead)
            .length ??
        0;

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: 1),
      ),
      leading: showLeading
          ? IconButton(
              icon: const Icon(
                LucideIcons.menu,
                color: AppColors.primaryText,
                size: 24,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            )
          : null,
      title: Text(
        title ?? 'SMS SERVICES',
        style: AppTextStyles.heading3.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primaryNavy,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                LucideIcons.bell,
                color: AppColors.primaryText,
                size: 24,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            context.push('/notifications');
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
