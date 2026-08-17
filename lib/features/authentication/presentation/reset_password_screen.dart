import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/providers.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _success = false;
  String? _errorMessage;

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.changePassword(_passwordController.text);
      setState(() {
        _success = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reset Password'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _success
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 72,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Password Reset Done',
                      style: AppTextStyles.heading2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your password has been reset successfully. You can now log in with your new password.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    AppPrimaryButton(
                      text: 'Go to Sign In',
                      onTap: () {
                        context.go('/login');
                      },
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Create New Password',
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Please enter your new password below.',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 36),

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

                      AppTextField(
                        label: 'New Password',
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
                      const SizedBox(height: 20),
                      AppTextField(
                        label: 'Confirm New Password',
                        hint: '••••••••',
                        controller: _confirmPasswordController,
                        isPassword: true,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Confirm Password is required';
                          }
                          if (val != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      AppPrimaryButton(
                        text: 'Update Password',
                        isLoading: _isLoading,
                        onTap: _handleReset,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
