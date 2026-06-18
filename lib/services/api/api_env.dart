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

  // API Nobuzero. Auth-nya HMAC + UserID.
  static const String nobuzeroBaseUrl = String.fromEnvironment(
    'LIVEGO_NOBUZERO_BASE_URL',
    defaultValue: 'https://nobuzero.my.id',
  );

  static const String nobuzeroUserId = String.fromEnvironment(
    'LIVEGO_USER_ID',
    defaultValue: '',
  );

  static const String nobuzeroSecret = String.fromEnvironment(
    'LIVEGO_SECRET',
    defaultValue: '',
  );

  static const Duration timeout = Duration(seconds: 18);

  /// True jika USER_ID dan SECRET sudah dikonfigurasi via --dart-define.
  static bool get hasLiveGoCredentials =>
      nobuzeroUserId.trim().isNotEmpty && nobuzeroSecret.trim().isNotEmpty;

  /// User ID tersensor untuk keperluan log/debug tanpa mengekspos ID asli secara penuh.
  static String get maskedUserId {
    final id = nobuzeroUserId.trim();
    if (id.isEmpty) return 'none';
    if (id.length < 8) return '***';
    return '${id.substring(0, 3)}...${id.substring(id.length - 4)}';
  }

  static void applyHeaders(HttpHeaders headers) {
    if (apiKey.isNotEmpty) {
      headers.set('X-API-Key', apiKey);
    }
    headers.set('Accept', 'application/json');
    headers.set('User-Agent', 'okhttp/4.12.0');
  }
}
