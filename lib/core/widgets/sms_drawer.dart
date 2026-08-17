import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../services/providers.dart';
import '../utils/date_formatter.dart';
import '../utils/localizations.dart';

class SmsDrawer extends ConsumerWidget {
  const SmsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final residenceState = ref.watch(residenceDetailsProvider);
    final localizations = AppLocalizations.of(context);
    final user = authState.value;
    final residence = residenceState.value;

    final name = user?.fullName ?? localizations.translate('profile');
    final unitText = residence != null 
        ? localizations.translate('unit', residence.unit.unitNumber)
        : '';
    final leaseExpiryText = residence != null
        ? localizations.translate(
            'lease_expires', 
            DateFormatter.formatShortDate(residence.lease.endDate),
          )
        : '';

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMS',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primaryNavy,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'SERVICES',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primaryNavy,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Resident Info Card
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryNavy, width: 1.5),
                          image: DecorationImage(
                            image: NetworkImage(
                              user?.avatarUrl ?? 
                              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=150',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.heading3.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (unitText.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                unitText,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                            if (leaseExpiryText.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                leaseExpiryText,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryNavy,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border),

            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: LucideIcons.user,
                    label: localizations.translate('profile'),
                    route: '/profile',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: LucideIcons.wrench,
                    label: localizations.translate('maintenance'),
                    route: '/maintenance',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: LucideIcons.creditCard,
                    label: localizations.translate('payments'),
                    route: '/payments',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: LucideIcons.shield,
                    label: localizations.translate('insurance_coverage'),
                    route: '/insurance',
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border),

            // Settings & Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: LucideIcons.settings,
                    label: localizations.translate('settings'),
                    route: '/settings',
                  ),
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    context: context,
                    icon: LucideIcons.logOut,
                    label: localizations.translate('log_out'),
                    textColor: AppColors.error,
                    iconColor: AppColors.error,
                    onTap: () {
                      ref.read(authServiceProvider).signOut();
                      context.go('/login');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    String? route,
    VoidCallback? onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final location = GoRouterState.of(context).matchedLocation;
    final isSelected = route != null && location.startsWith(route);

    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close Drawer
        if (onTap != null) {
          onTap();
        } else if (route != null) {
          context.go(route);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.border.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? (isSelected ? AppColors.primaryNavy : AppColors.secondaryText),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor ?? (isSelected ? AppColors.primaryNavy : AppColors.primaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
