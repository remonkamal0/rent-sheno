import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/api/supabase_client.dart';
import 'core/database/shared_prefs.dart';
import 'core/services/providers.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final sharedPrefsService = SharedPrefsService(prefs);

  // Initialize Supabase (falls back to mock mode if credentials are placeholders)
  await SupabaseClientHelper.initialize();

  runApp(
    ProviderScope(
      overrides: [
        // Override the shared preferences provider with the initialized instance
        sharedPrefsProvider.overrideWithValue(sharedPrefsService),
      ],
      child: const SmsServicesApp(),
    ),
  );
}
