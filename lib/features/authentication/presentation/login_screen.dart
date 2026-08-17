import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/localizations.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final secureStorage = ref.read(secureStorageProvider);
    final sharedPrefs = ref.read(sharedPrefsProvider);
    
    final rememberMe = sharedPrefs.getRememberMe();
    setState(() {
      _rememberMe = rememberMe;
    });

    if (rememberMe) {
      final email = await secureStorage.getRememberedEmail();
      if (email != null) {
        _emailController.text = email;
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final sharedPrefs = ref.read(sharedPrefsProvider);
      
      final success = await authService.signIn(
        _emailController.text,
        _passwordController.text,
        _rememberMe,
      );

      if (success) {
        await sharedPrefs.setRememberMe(_rememberMe);
        if (mounted) {
          context.go('/home');
        }
      } else {
        setState(() {
          _errorMessage = AppLocalizations.of(context).translate('invalid_auth');
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleLanguage() {
    final currentLocale = ref.read(localeProvider);
    final newLangCode = currentLocale.languageCode == 'en' ? 'ar' : 'en';
    
    ref.read(localeProvider.notifier).state = Locale(newLangCode);
    ref.read(sharedPrefsProvider).setLanguage(newLangCode);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // Logo Title
                  Text(
                    localizations.translate('app_title'),
                    style: AppTextStyles.display.copyWith(
                      color: AppColors.primaryNavy,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  Text(
                    localizations.translate('login_subtitle'),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error, width: 1),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email
                  AppTextField(
                    label: localizations.translate('email'),
                    hint: 'email@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password
                  AppTextField(
                    label: localizations.translate('password'),
                    hint: '••••••••',
                    controller: _passwordController,
                    isPassword: true,
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Password is required';
                      }
                      if (val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Remember me & Forgot Password Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primaryNavy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _rememberMe = !_rememberMe;
                              });
                            },
                            child: Text(
                              localizations.translate('remember_me'),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.push('/forgot-password'),
                        child: Text(
                          localizations.translate('forgot_password'),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Sign In button
                  AppPrimaryButton(
                    text: localizations.translate('sign_in'),
                    isLoading: _isLoading,
                    onTap: _handleLogin,
                  ),
                  const SizedBox(height: 48),

                  // Language Switcher Toggle
                  Center(
                    child: GestureDetector(
                      onTap: _toggleLanguage,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border, width: 1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isArabic ? 'English | EN' : 'عربي | AR',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
