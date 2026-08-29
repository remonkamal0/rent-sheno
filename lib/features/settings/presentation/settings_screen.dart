import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _darkMode = ref.read(themeModeProvider) == ThemeMode.dark;
  }

  void _showLanguageSelector() {
    final currentLang = ref.read(localeProvider).languageCode;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.cardColor,
          title: Text(
            AppLocalizations.of(context).translate('lang_label'),
            style: AppTextStyles.heading3.copyWith(
              fontWeight: FontWeight.bold,
              color: context.primaryTextColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption('en', 'English', currentLang),
              const Divider(height: 1),
              _buildLanguageOption('es', 'Español', currentLang),
              const Divider(height: 1),
              _buildLanguageOption('ar', 'العربية', currentLang),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String code, String label, String currentLang) {
    final isSelected = currentLang == code;
    return ListTile(
      title: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: context.primaryTextColor,
        ),
      ),
      trailing: isSelected
          ? Icon(
              LucideIcons.check,
              color: context.isDarkMode
                  ? AppColors.lightBlue
                  : AppColors.primaryNavy,
              size: 18,
            )
          : null,
      onTap: () {
        ref.read(localeProvider.notifier).state = Locale(code);
        ref.read(sharedPrefsProvider).setLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final langCode = ref.watch(localeProvider).languageCode;
    String langName = 'English';
    if (langCode == 'es') {
      langName = 'Español';
    } else if (langCode == 'ar') {
      langName = 'العربية';
    }
    final themeAccentIconColor = context.isDarkMode
        ? AppColors.lightBlue
        : AppColors.primaryNavy;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else if (context.canPop()) {
              context.pop();
            } else {
              final user = ref.read(authServiceProvider).currentUser;
              if (user?.role == 'landlord' || user?.role == 'manager') {
                context.go('/manager/home');
              } else {
                context.go('/');
              }
            }
          },
        ),
        title: Text(
          localizations.translate('settings'),
          style: AppTextStyles.heading3.copyWith(
            color: context.primaryTextColor,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // 1. Language preference
            _buildSectionHeader(
              AppLocalizations.of(context).text('Preferences'),
            ),
            Card(
              color: context.cardColor,
              child: ListTile(
                leading: Icon(
                  LucideIcons.languages,
                  color: themeAccentIconColor,
                ),
                title: Text(
                  localizations.translate('lang_label'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.primaryTextColor,
                  ),
                ),
                trailing: Text(
                  langName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: themeAccentIconColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _showLanguageSelector,
              ),
            ),
            const SizedBox(height: 16),

            // 3. Theme & Security
            _buildSectionHeader(
              AppLocalizations.of(context).text('Theme & Security'),
            ),
            Card(
              color: context.cardColor,
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: localizations.translate('dark_mode'),
                    value: _darkMode,
                    onChanged: (val) {
                      setState(() => _darkMode = val);
                      ref.read(themeModeProvider.notifier).toggleTheme(val);
                    },
                  ),
                  Divider(height: 1, color: context.borderColor),
                  ListTile(
                    leading: Icon(
                      LucideIcons.lock,
                      color: themeAccentIconColor,
                    ),
                    title: Text(
                      localizations.translate('change_pw'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.primaryTextColor,
                      ),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: context.secondaryTextColor,
                    ),
                    onTap: () => context.push('/change-password'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Legal & About
            _buildSectionHeader(
              AppLocalizations.of(context).text('Information'),
            ),
            Card(
              color: context.cardColor,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      LucideIcons.fileText,
                      color: themeAccentIconColor,
                    ),
                    title: Text(
                      localizations.translate('privacy_policy'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.primaryTextColor,
                      ),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: context.secondaryTextColor,
                    ),
                    onTap: () {
                      _showDialogInfo(
                        'Privacy Policy',
                        AppLocalizations.of(context).text(
                          'This app complies with privacy regulation standards.',
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: context.borderColor),
                  ListTile(
                    leading: Icon(
                      LucideIcons.helpCircle,
                      color: themeAccentIconColor,
                    ),
                    title: Text(
                      localizations.translate('terms'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.primaryTextColor,
                      ),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: context.secondaryTextColor,
                    ),
                    onTap: () {
                      _showDialogInfo(
                        AppLocalizations.of(context).text('Terms & Conditions'),
                        'SMS Services rules represent rental policy standards.',
                      );
                    },
                  ),
                  Divider(height: 1, color: context.borderColor),
                  ListTile(
                    leading: Icon(
                      LucideIcons.info,
                      color: themeAccentIconColor,
                    ),
                    title: Text(
                      localizations.translate('about'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.primaryTextColor,
                      ),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: context.secondaryTextColor,
                    ),
                    onTap: () {
                      _showDialogInfo(
                        'About SMS Services',
                        'SMS Services Tenant Portal v1.0.0. Complete property management in your pocket.',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: context.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.error, width: 1),
              ),
              child: ListTile(
                leading: const Icon(LucideIcons.trash2, color: AppColors.error),
                title: Text(
                  AppLocalizations.of(context).text('Delete Account'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                trailing: const Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: AppColors.error,
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: context.cardColor,
                        title: Text(
                          AppLocalizations.of(context).text('Delete Account'),
                          style: TextStyle(color: AppColors.error),
                        ),
                        content: Text(
                          AppLocalizations.of(context).text(
                            'Are you sure you want to permanently delete your account? This action is irreversible and all your data will be permanently deleted.',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              AppLocalizations.of(context).text('Cancel'),
                              style: TextStyle(
                                color: context.secondaryTextColor,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).text('Delete Permanently'),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true) {
                    try {
                      await ref.read(authServiceProvider).deleteAccount();
                      if (context.mounted) {
                        context.go('/login');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(
                                context,
                              ).text('Account deleted successfully.'),
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(
                                context,
                              ).text('Error: {}', e.toString()),
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          color: context.secondaryTextColor,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      activeColor: AppColors.primaryNavy,
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: context.primaryTextColor,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  void _showDialogInfo(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardColor,
        title: Text(
          title,
          style: AppTextStyles.heading3.copyWith(
            fontWeight: FontWeight.bold,
            color: context.primaryTextColor,
          ),
        ),
        content: Text(
          content,
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.secondaryTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).text('OK'),
              style: TextStyle(
                color: context.isDarkMode
                    ? AppColors.lightBlue
                    : AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
