import 'dart:io';

import 'livego_api_signer.dart';

class ApiEnv {
  // Single source of truth for the generated Nobuzero LiveGo API.
  static const String baseUrl = String.fromEnvironment(
    'LIVEGO_BASE_URL',
    defaultValue: 'https://nobuzero.my.id',
  );
  static const String userId = String.fromEnvironment(
    'LIVEGO_USER_ID',
    defaultValue: 'lg_cbbc2c523c3af527',
  );
  static const String secret = String.fromEnvironment(
    'LIVEGO_SECRET',
    defaultValue:
        'c3f6a21f55e60e5c3057271c580200faaf59e0c48f8c8a4fa2cefef925f31a9a',
  );

  static const Duration timeout = Duration(seconds: 10);

  static Uri apiV2Uri(String path, Map<String, String> query) {
    final base = Uri.parse(baseUrl);
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final apiPath = cleanPath.startsWith('/api/v2/')
        ? cleanPath
        : '/api/v2$cleanPath';
    return base.replace(
      path: apiPath,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static void applyHeaders(HttpHeaders headers, {required String method, required Uri uri}) {
    LiveGoApiSigner.apply(headers, method: method, uri: uri);
  }
}
