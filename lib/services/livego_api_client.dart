import 'dart:convert';

import 'package:http/http.dart' as http;

import 'livego_hmac.dart';

class LiveGoApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-drama.dobda.id',
  );

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
    bool signed = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    final headers = signed
        ? LiveGoHmac.headers(method: 'GET', uri: uri)
        : const {'Accept': 'application/json'};

    final res = await http.get(uri, headers: headers).timeout(
          const Duration(seconds: 18),
        );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    if (res.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(res.body);

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return {
      'success': true,
      'data': decoded,
    };
  }
}
