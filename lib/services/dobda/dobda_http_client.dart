import 'dart:convert';
import 'dart:io';

import '../api/api_env.dart';

/// Low-level API v2 HTTP client.
///
/// Keep network transport here so provider implementation stays focused on
/// endpoints, parsing, and mapping.
class DobdaHttpClient {
  const DobdaHttpClient._();

  static Future<Map<String, dynamic>> getJson(
    String path,
    Map<String, String> query,
  ) async {
    final uri = _buildUri(path, query);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(ApiEnv.timeout);
      ApiEnv.applyHeaders(request.headers, method: 'GET', uri: uri);

      final response = await request.close().timeout(ApiEnv.timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('LiveGO API ${response.statusCode} ${uri.path}: $body');
      }
      if (body.trim().isEmpty) return <String, dynamic>{};

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'success': true, 'data': decoded};
    } finally {
      client.close(force: true);
    }
  }

  static Uri _buildUri(String path, Map<String, String> query) {
    return ApiEnv.apiV2Uri(path, query);
  }

}
