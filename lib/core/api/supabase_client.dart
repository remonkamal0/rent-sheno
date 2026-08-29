import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/constants/app_constants.dart';

class SupabaseClientHelper {
  static bool _isMockMode = true;

  static bool get isMockMode => _isMockMode;

  static Future<void> initialize() async {
    final url = AppConstants.supabaseUrl;
    final key = AppConstants.supabaseAnonKey;

    if (url.startsWith('https://placeholder-url') || key == 'placeholder-key') {
      if (kDebugMode) {
        print(
          'SMS SERVICES: Running in MOCK DATA mode. (Placeholder Supabase URL or Key found)',
        );
      }
      _isMockMode = true;
      return;
    }

    try {
      await Supabase.initialize(url: url, anonKey: key);
      _isMockMode = false;
      if (kDebugMode) {
        print('SMS SERVICES: Connected to Supabase successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'SMS SERVICES ERROR: Failed to connect to Supabase: $e. Falling back to MOCK DATA mode.',
        );
      }
      _isMockMode = true;
    }
  }

  static SupabaseClient get client {
    if (_isMockMode) {
      throw StateError('Cannot access SupabaseClient in Mock mode.');
    }
    return Supabase.instance.client;
  }
}
