import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class AppPrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? icon;

  const AppPrimaryButton({
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.icon,
    super.key,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onTap != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _scale = 0.96) : null,
      onTapUp: isEnabled ? (_) => setState(() => _scale = 1.0) : null,
      onTapCancel: isEnabled ? () => setState(() => _scale = 1.0) : null,
      onTap: isEnabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: isEnabled ? AppColors.primaryNavy : AppColors.border,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.text,
                      style: AppTextStyles.button,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AppSecondaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? icon;

  const AppSecondaryButton({
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.icon,
    super.key,
  });

  @override
  State<AppSecondaryButton> createState() => _AppSecondaryButtonState();
}

class _AppSecondaryButtonState extends State<AppSecondaryButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onTap != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _scale = 0.96) : null,
      onTapUp: isEnabled ? (_) => setState(() => _scale = 1.0) : null,
      onTapCancel: isEnabled ? () => setState(() => _scale = 1.0) : null,
      onTap: isEnabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEnabled ? AppColors.primaryNavy : AppColors.border,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryNavy),
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: AppColors.primaryNavy, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.text,
                      style: AppTextStyles.button.copyWith(
                        color: isEnabled ? AppColors.primaryNavy : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
