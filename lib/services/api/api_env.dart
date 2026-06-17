import 'dart:io';

class ApiEnv {
  // Ganti API utama cukup dari file ini.
  static const String baseUrl = 'https://priv-api.anichin.bio';
  static const String apiKey = 'dk_live_c261cb5920f82cf971e29edf0c8183d8';

  // API v2 Nobuzero untuk thin-client mapping.
  static const String dobdaBaseUrl = 'https://nobuzero.my.id';
  static const String dobdaSecret = '';

  static const Duration timeout = Duration(seconds: 18);

  static void applyHeaders(HttpHeaders headers) {
    headers.set('X-API-Key', apiKey);
    headers.set('Accept', 'application/json');
    headers.set('User-Agent', 'okhttp/4.12.0');
  }
}
