import 'dart:convert';
import 'dart:io';

import '../api/api_env.dart';
import '../api/dobda_hmac_signer.dart';

/// Low-level Dobda/Nobuzero HTTP/HMAC client.
class DobdaHttpClient {
  const DobdaHttpClient._();

  static Future<Map<String, dynamic>> getJson(
    String path,
    Map<String, String> query,
  ) async {
    // Build URI sekali supaya parameter query konsisten untuk request dan signing.
    final baseUri = Uri.parse(ApiEnv.dobdaBaseUrl);
    final uri = baseUri.replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(ApiEnv.timeout);

      // Kirim X-User-Id dan Secret dari ApiEnv ke signer.
      final headers = DobdaHmacSigner.headers(
        method: 'GET',
        uri: uri,
        secret: ApiEnv.dobdaSecret,
        userId: ApiEnv.dobdaUserId,
      );

      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      final response = await request.close().timeout(ApiEnv.timeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('NOBUZERO API ${response.statusCode} ${uri.path}: $body');
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
}
