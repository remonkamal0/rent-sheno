class AppConstants {
  AppConstants._();

  // Supabase Configurations (to be set via env variables or constants)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder-url.supabase.co',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-key',
  );

  // Storage keys
  static const String keyUserToken = 'user_token';
  static const String keyUserEmail = 'user_email';
  static const String keyRememberMe = 'remember_me';
  static const String keyLanguage = 'preferred_lang';
  static const String keyDarkMode = 'dark_mode';

  // Notification Channels
  static const String notificationChannelId = 'sms_services_channel';
  static const String notificationChannelName = 'SMS Services Notifications';
  static const String notificationChannelDescription = 'Notifications for lease, maintenance, and payment updates';

  // Demo / Fallback Data
  static const String demoEmail = 'john.doe@example.com';
  static const String demoPassword = 'password123';
  static const String demoFullName = 'John Doe';
  static const String demoPhone = '+1 (555) 019-2834';
  static const String demoPropertyName = '123 Maple St';
  static const String demoUnitNumber = 'Apt 402';
  static const String demoLeaseStart = '2024-01-01';
  static const String demoLeaseEnd = '2024-12-31';
}
