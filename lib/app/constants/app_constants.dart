class AppConstants {
  AppConstants._();

  // Supabase configuration. Build-time values can still override these defaults.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://edcqfrspugydxnvarjmg.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkY3FmcnNwdWd5ZHhudmFyam1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5OTgzNjMsImV4cCI6MjEwMzU3NDM2M30.vyFAXvMdH-mfuJh77Wb5FBcJKP3xJP3FoQKbcs2Dkls',
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
  static const String notificationChannelDescription =
      'Notifications for lease, maintenance, and payment updates';

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
