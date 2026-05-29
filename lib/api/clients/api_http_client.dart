import 'dart:convert';
import 'dart:io';

import '../auth/hmac_signer.dart';

class ApiHttpClient {
  final String baseUrl;
  final String secret;
  final Duration timeout;

  const ApiHttpClient({
    required this.baseUrl,
    required this.secret,
    this.timeout = const Duration(seconds: 18),
  });

  Future<Map<String, dynamic>> getJson(
    String path,
    Map<String, String> query, {
    bool signed = true,
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );

    print('LIVEGO API => GET $uri');

    final request = await HttpClient().getUrl(uri).timeout(timeout);

    final headers = signed
        ? HmacSigner.signedHeaders(method: 'GET', uri: uri, secret: secret)
        : const <String, String>{
            'Accept': 'application/json',
            'User-Agent': 'okhttp/4.12.0',
          };

    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }

    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join();

    final preview = body.length > 280 ? body.substring(0, 280) : body;
    print('LIVEGO API <= ${response.statusCode} $preview');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: $preview');
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'success': true, 'data': decoded};
  }
}
