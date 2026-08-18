import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/services/providers.dart';
import '../core/utils/localizations.dart';

class SmsServicesApp extends ConsumerWidget {
  const SmsServicesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    final isArabic = locale.languageCode == 'ar';
    
    final baseLightTheme = AppTheme.lightTheme;
    final baseDarkTheme = AppTheme.darkTheme;

    final lightTheme = isArabic
        ? baseLightTheme.copyWith(
            textTheme: GoogleFonts.cairoTextTheme(baseLightTheme.textTheme),
          )
        : baseLightTheme.copyWith(
            textTheme: GoogleFonts.interTextTheme(baseLightTheme.textTheme),
          );

    final darkTheme = isArabic
        ? baseDarkTheme.copyWith(
            textTheme: GoogleFonts.cairoTextTheme(baseDarkTheme.textTheme),
          )
        : baseDarkTheme.copyWith(
            textTheme: GoogleFonts.interTextTheme(baseDarkTheme.textTheme),
          );

    return MaterialApp.router(
      title: 'SMS SERVICES',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
        Locale('ar', ''),
      ],
    );
  }
}
