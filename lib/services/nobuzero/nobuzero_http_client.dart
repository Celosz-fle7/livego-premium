import 'dart:convert';
import 'dart:io';

import '../api/api_env.dart';
import '../api/nobuzero_hmac_signer.dart';

class LiveGoAuthConfigException implements Exception {
  final String message;
  const LiveGoAuthConfigException(this.message);
  @override
  String toString() => 'LiveGoAuthConfigException: $message';
}

class LiveGoAuthException implements Exception {
  final int statusCode;
  final String message;
  const LiveGoAuthException(this.statusCode, this.message);
  @override
  String toString() => 'LiveGoAuthException($statusCode): $message';
}

/// Low-level Nobuzero/Nobuzero HTTP/HMAC client.
class NobuzeroHttpClient {
  const NobuzeroHttpClient._();

  static Future<Map<String, dynamic>> getJson(
    String path,
    Map<String, String> query,
  ) async {
    // Auth Guard: Jangan hit network jika credentials kosong.
    if (!ApiEnv.hasLiveGoCredentials) {
      throw const LiveGoAuthConfigException(
        'LIVEGO_USER_ID / LIVEGO_SECRET belum dikonfigurasi. Build APK dengan --dart-define.',
      );
    }

    final baseUri = Uri.parse(ApiEnv.nobuzeroBaseUrl);
    final uri = baseUri.replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(ApiEnv.timeout);

      final headers = NobuzeroHmacSigner.headers(
        method: 'GET',
        uri: uri,
        secret: ApiEnv.nobuzeroSecret,
        userId: ApiEnv.nobuzeroUserId,
      );

      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      final response = await request.close().timeout(ApiEnv.timeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 401 || response.statusCode == 403) {
        String errorMessage = response.statusCode == 401
            ? 'Auth gagal / signature salah / user kosong'
            : 'Platform tidak diizinkan untuk user ini';

        try {
          final json = jsonDecode(body);
          if (json is Map && json['message'] != null) {
            errorMessage = '${json['message']}';
          }
        } catch (_) {}

        throw LiveGoAuthException(response.statusCode, errorMessage);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('NOBUZERO API ${response.statusCode} ${uri.path}');
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
