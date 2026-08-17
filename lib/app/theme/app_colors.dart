import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryNavy = Color(0xFF003F70);
  static const Color darkNavy = Color(0xFF002E5D);
  static const Color lightBlue = Color(0xFFE8F0FF);
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF071426);
  static const Color secondaryText = Color(0xFF4B5563);
  static const Color border = Color(0xFFC5CDD8);
  
  static const Color success = Color(0xFF138A45);
  static const Color successBg = Color(0xFFE4F6EB);
  
  static const Color warning = Color(0xFFD85312);
  static const Color warningBg = Color(0xFFFFF0E8);
  
  static const Color error = Color(0xFFCF1010);
  static const Color errorBg = Color(0xFFFFE7E5);
}

extension ThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get primaryTextColor => isDarkMode ? Colors.white : AppColors.primaryText;
  Color get secondaryTextColor => isDarkMode ? Colors.white70 : AppColors.secondaryText;
  Color get cardColor => isDarkMode ? const Color(0xFF1E293B) : AppColors.cardBackground;
  Color get backgroundColor => isDarkMode ? const Color(0xFF0F172A) : AppColors.background;
  Color get borderColor => isDarkMode ? const Color(0xFF334155) : AppColors.border;
}
