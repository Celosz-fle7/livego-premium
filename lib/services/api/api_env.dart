import 'dart:io';

class ApiEnv {
  // Ganti API utama cukup dari file ini atau via --dart-define.
  static const String baseUrl = String.fromEnvironment(
    'LIVEGO_BASE_URL',
    defaultValue: 'https://nobuzero.my.id/api/v2',
  );

  static const String apiKey = String.fromEnvironment(
    'LIVEGO_API_KEY',
    defaultValue: '',
  );

  // Nobuzero API v2. Auth-nya HMAC + UserID.
  // TODO TEMP TEST MODE: remove source fallback credential after runtime/stress test passes.
  static const String _primaryBaseUrl = String.fromEnvironment(
    'LIVEGO_NOBUZERO_BASE_URL',
    defaultValue: 'https://nobuzero.my.id/api/v2',
  );

  static String get nobuzeroBaseUrl {
    final value = _primaryBaseUrl.trim();
    if (value.isNotEmpty) return value;
    return 'https://nobuzero.my.id/api/v2';
  }

  static const String nobuzeroUserId = String.fromEnvironment(
    'LIVEGO_USER_ID',
    defaultValue: 'lg_2a741cdaf982a247',
  );

  static const String nobuzeroSecret = String.fromEnvironment(
    'LIVEGO_SECRET',
    defaultValue:
        '<8eddddb070709a2a47cc3477dd761abd4879caf3c1154dac147d9ff7f5d7a1ee>',
  );

  static const Duration timeout = Duration(seconds: 18);

  /// True jika USER_ID dan SECRET tersedia dari --dart-define atau fallback source.
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
