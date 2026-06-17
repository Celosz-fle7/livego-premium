import 'dart:io';

class ApiEnv {
  // Ganti API utama cukup dari file ini atau via --dart-define.
  static const String baseUrl = String.fromEnvironment(
    'LIVEGO_BASE_URL',
    defaultValue: 'https://nobuzero.my.id',
  );

  static const String apiKey = String.fromEnvironment(
    'LIVEGO_API_KEY',
    defaultValue: '',
  );

  // API kedua Dobda/Nobuzero. Auth-nya HMAC + UserID.
  static const String dobdaBaseUrl = String.fromEnvironment(
    'LIVEGO_DOBDA_BASE_URL',
    defaultValue: 'https://nobuzero.my.id',
  );

  static const String dobdaUserId = String.fromEnvironment(
    'LIVEGO_USER_ID',
    defaultValue: '',
  );

  static const String dobdaSecret = String.fromEnvironment(
    'LIVEGO_SECRET',
    defaultValue: '',
  );

  static const Duration timeout = Duration(seconds: 18);

  static void applyHeaders(HttpHeaders headers) {
    if (apiKey.isNotEmpty) {
      headers.set('X-API-Key', apiKey);
    }
    headers.set('Accept', 'application/json');
    headers.set('User-Agent', 'okhttp/4.12.0');
  }
}
