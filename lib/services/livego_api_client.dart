import 'dart:convert';
import 'dart:io';

import 'api_config.dart';
import 'hmac_signer.dart';

class LiveGoApiClient {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
    bool signed = true,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(ApiConfig.timeout);

      for (final entry in ApiConfig.defaultHeaders.entries) {
        request.headers.set(entry.key, entry.value);
      }

      if (signed) {
        final headers = const HmacSigner(ApiConfig.apiSecret).sign('GET', uri);
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }
      }

      final response = await request.close().timeout(ApiConfig.timeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('API ${response.statusCode} ${uri.path}: $body');
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'success': true, 'data': decoded};
    } finally {
      client.close(force: true);
    }
  }
}
