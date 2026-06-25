import 'dart:io';

import 'livego_api_signer.dart';

class ApiEnv {
  static const String baseUrl = String.fromEnvironment(
    'LIVEGO_BASE_URL',
    defaultValue: 'https://nobuzero.my.id',
  );
  static const String userId = String.fromEnvironment(
    'LIVEGO_USER_ID',
    defaultValue: 'lg_9fd9128c24c21896',
  );
  static const String secret = String.fromEnvironment(
    'LIVEGO_SECRET',
    defaultValue: '3285761f7b7ab8b0141cb54da274849a921b9149a51c7a22f2832c695d90f753',
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

  static void applyHeaders(HttpHeaders headers,
      {required String method, required Uri uri}) {
    LiveGoApiSigner.apply(headers, method: method, uri: uri);
  }
}
