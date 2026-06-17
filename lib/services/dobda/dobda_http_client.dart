import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

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
      request.headers.set('Accept', 'application/json');
      request.headers.set('User-Agent', 'LiveGo/1.0');
      _applyAuthHeaders(request.headers, uri);

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
    final base = Uri.parse(ApiEnv.nobuzeroApiBaseUrl);
    final cleanBasePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullPath = cleanPath.startsWith(cleanBasePath)
        ? cleanPath
        : '$cleanBasePath$cleanPath';
    return base.replace(
      path: fullPath,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static void _applyAuthHeaders(HttpHeaders headers, Uri uri) {
    final userId = ApiEnv.nobuzeroUserId.trim();
    final secret = ApiEnv.nobuzeroSecret.trim();
    if (userId.isEmpty || secret.isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final fullPathWithQuery = uri.hasQuery
        ? '${uri.path}?${uri.query}'
        : uri.path;
    final payload = 'GET:$fullPathWithQuery:$timestamp';
    final signature = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(payload))
        .toString();

    headers.set('X-User-Id', userId);
    headers.set('X-Timestamp', timestamp);
    headers.set('X-Signature', signature);
  }
}
