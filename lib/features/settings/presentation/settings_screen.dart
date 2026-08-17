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
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _paymentNotifications = true;
  bool _maintenanceNotifications = true;
  bool _insuranceAlerts = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _darkMode = ref.read(themeModeProvider) == ThemeMode.dark;
  }

  void _toggleLanguage() {
    final currentLocale = ref.read(localeProvider);
    final newLangCode = currentLocale.languageCode == 'en' ? 'es' : 'en';

    ref.read(localeProvider.notifier).state = Locale(newLangCode);
    ref.read(sharedPrefsProvider).setLanguage(newLangCode);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isSpanish = ref.watch(localeProvider).languageCode == 'es';
    final themeAccentIconColor = context.isDarkMode ? AppColors.lightBlue : AppColors.primaryNavy;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          localizations.translate('settings'),
          style: AppTextStyles.heading3.copyWith(color: context.primaryTextColor),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // 1. Language preference
            _buildSectionHeader('Preferences'),
            Card(
              color: context.cardColor,
              child: ListTile(
                leading: Icon(LucideIcons.languages, color: themeAccentIconColor),
                title: Text(
                  localizations.translate('lang_label'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.primaryTextColor,
                  ),
                ),
                trailing: Text(
                  isSpanish ? 'Español' : 'English',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: themeAccentIconColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _toggleLanguage,
              ),
            ),
            const SizedBox(height: 16),

            // 2. Notification switches
            _buildSectionHeader('Notifications'),
            Card(
              color: context.cardColor,
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: localizations.translate('push_notif'),
                    value: _pushNotifications,
                    onChanged: (val) => setState(() => _pushNotifications = val),
                  ),
                  Divider(height: 1, color: context.borderColor),
                  _buildSwitchTile(
                    title: localizations.translate('email_notif'),
                    value: _emailNotifications,
                    onChanged: (val) => setState(() => _emailNotifications = val),
                  ),
                  Divider(height: 1, color: context.borderColor),
                  _buildSwitchTile(
                    title: localizations.translate('pay_notif'),
                    value: _paymentNotifications,
                    onChanged: (val) => setState(() => _paymentNotifications = val),
                  ),
                  Divider(height: 1, color: context.borderColor),
                  _buildSwitchTile(
                    title: localizations.translate('maint_notif'),
                    value: _maintenanceNotifications,
                    onChanged: (val) => setState(() => _maintenanceNotifications = val),
                  ),
                  Divider(height: 1, color: context.borderColor),
                  _buildSwitchTile(
                    title: localizations.translate('ins_alert'),
                    value: _insuranceAlerts,
                    onChanged: (val) => setState(() => _insuranceAlerts = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Theme & Security
            _buildSectionHeader('Theme & Security'),
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
                    leading: Icon(LucideIcons.lock, color: themeAccentIconColor),
                    title: Text(
                      localizations.translate('change_pw'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.primaryTextColor,
                      ),
                    ),
                    trailing: Icon(LucideIcons.chevronRight, size: 18, color: context.secondaryTextColor),
                    onTap: () => context.push('/change-password'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Legal & About
            _buildSectionHeader('Information'),
            Card(
              color: context.cardColor,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(LucideIcons.fileText, color: themeAccentIconColor),
                    title: Text(
                      localizations.translate('privacy_policy'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.primaryTextColor,
                      ),
                    ),
                    trailing: Icon(LucideIcons.chevronRight, size: 18, color: context.secondaryTextColor),
                    onTap: () {
                      _showDialogInfo('Privacy Policy', 'This app complies with privacy regulation standards.');
                    },
                  ),
                  Divider(height: 1, color: context.borderColor),
                  ListTile(
                    leading: Icon(LucideIcons.helpCircle, color: themeAccentIconColor),
                    title: Text(
                      localizations.translate('terms'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.primaryTextColor,
                      ),
                    ),
                    trailing: Icon(LucideIcons.chevronRight, size: 18, color: context.secondaryTextColor),
                    onTap: () {
                      _showDialogInfo('Terms & Conditions', 'SMS Services rules represent rental policy standards.');
                    },
                  ),
                  Divider(height: 1, color: context.borderColor),
                  ListTile(
                    leading: Icon(LucideIcons.info, color: themeAccentIconColor),
                    title: Text(
                      localizations.translate('about'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.primaryTextColor,
                      ),
                    ),
                    trailing: Icon(LucideIcons.chevronRight, size: 18, color: context.secondaryTextColor),
                    onTap: () {
                      _showDialogInfo('About SMS Services', 'SMS Services Tenant Portal v1.0.0. Complete property management in your pocket.');
                    },
                  ),
                ],
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
          style: AppTextStyles.bodyMedium.copyWith(color: context.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: context.isDarkMode ? AppColors.lightBlue : AppColors.primaryNavy, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
