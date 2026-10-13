import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Client HTTP untuk MovieBox API (H5 Gateway).
class MovieBoxClient {
  static const String baseUrl = 'https://movieboxhd.net/wefeed-h5api-bff';
  static const String cdnBaseUrl = 'https://macdn.aoneroom.com';

  final http.Client _httpClient = http.Client();

  Map<String, String> get _headers => {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'X-Client-Info': jsonEncode({'timezone': 'Asia/Jakarta'}),
        'X-Request-Lang': 'id',
      };

  /// Ambil feed tab/kategori dari MovieBox.
  Future<Map<String, dynamic>> fetchTabOperating({String tabCode = 'HOME'}) async {
    final uri = Uri.parse('$baseUrl/tab-operating?tabCode=$tabCode');
    try {
      final response = await _httpClient.get(uri, headers: _headers).timeout(
            const Duration(seconds: 12),
          );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['code'] == 0) {
          return decoded['data'] as Map<String, dynamic>? ?? {};
        }
      }
    } catch (e) {
      debugPrint('[MovieBoxClient] fetchTabOperating error: $e');
    }
    return {};
  }

  /// Ambil detail konten (metadata, seasons, jumlah episode) berdasarkan subjectId.
  Future<Map<String, dynamic>> fetchDetail(String subjectId) async {
    final uri = Uri.parse('$baseUrl/detail?subjectId=$subjectId');
    try {
      final response = await _httpClient.get(uri, headers: _headers).timeout(
            const Duration(seconds: 12),
          );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['code'] == 0) {
          return decoded['data'] as Map<String, dynamic>? ?? {};
        }
      }
    } catch (e) {
      debugPrint('[MovieBoxClient] fetchDetail error: $e');
    }
    return {};
  }
}
