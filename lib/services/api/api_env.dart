import 'dart:io';

class ApiEnv {
  // Ganti API utama cukup dari file ini.
  static const String baseUrl = 'https://priv-api.anichin.bio';
  static const String apiKey = 'dk_live_c261cb5920f82cf971e29edf0c8183d8';

  // API v2 Nobuzero untuk thin-client mapping.
  static const String nobuzeroApiBaseUrl = String.fromEnvironment(
    'NOBUZERO_API_BASE_URL',
    defaultValue: 'https://nobuzero.my.id/api/v2',
  );
  static const String nobuzeroUserId = String.fromEnvironment(
    'NOBUZERO_USER_ID',
    defaultValue: 'lg_2a741cdaf982a247',
  );
  static const String nobuzeroSecret = String.fromEnvironment(
    'NOBUZERO_SECRET',
    defaultValue: '8eddddb070709a2a47cc3477dd761abd4879caf3c1154dac147d9ff7f5d7a1ee',
  );

  static bool get isNobuzeroStaging =>
      nobuzeroApiBaseUrl.contains('/api/staging/v2');

  static const Duration timeout = Duration(seconds: 10);

  static void applyHeaders(HttpHeaders headers) {
    headers.set('X-API-Key', apiKey);
    headers.set('Accept', 'application/json');
    headers.set('User-Agent', 'okhttp/4.12.0');
  }
}
