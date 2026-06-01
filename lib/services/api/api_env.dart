import 'dart:io';

class ApiEnv {
  // Ganti API utama cukup dari file ini.
  static const String baseUrl = 'https://priv-api.anichin.bio';
  static const String apiKey = 'dk_live_c261cb5920f82cf971e29edf0c8183d8';

  // API kedua Dobda. Auth-nya HMAC, bukan X-API-Key.
  static const String dobdaBaseUrl = 'https://api-drama.dobda.id';
  static const String dobdaSecret = '22dfb2b849814054af0491ff2ee3ffe33989313d7d38e97aae659757a4cf8960';

  static const Duration timeout = Duration(seconds: 18);

  static void applyHeaders(HttpHeaders headers) {
    headers.set('X-API-Key', apiKey);
    headers.set('Accept', 'application/json');
    headers.set('User-Agent', 'okhttp/4.12.0');
  }
}
