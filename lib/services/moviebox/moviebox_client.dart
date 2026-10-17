import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Network Client untuk MovieBox API (Transsion Mobile Istio-Envoy Gateway).
/// Menggunakan algoritma signature HMAC-MD5 persisten dan endpoint mobile bff resmi.
class MovieBoxClient {
  static MovieBoxClient? _instance;
  static MovieBoxClient get instance => _instance ??= MovieBoxClient._();

  MovieBoxClient._();

  static const String baseUrl = 'https://api4sg.aoneroom.com';

  /// Gateway Secret Online di-decode dari Base64
  static final List<int> _gatewaySecret =
      base64.decode('76iRl07s0xSN9jqmEWAt79EBJZulIQIsV64FZr2O');

  /// Bearer Auth Token
  static const String _authToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOjcxMDAyMTgxODE5MDE3NjcyMjQsImV4cCI6MTc5OTY3NDk2MSwiaWF0IjoxNzkxODk4NjYxfQ.yJOY1NK6GVBuLKyGbJ3XyZXcBsfui_ML_vcmr0KLQRM';

  /// Client Info Device Headers
  static final String _clientInfo = jsonEncode({
    'model': 'Infinix X6870',
    'system_language': 'in',
    'net': 'NETWORK_WIFI',
    'region': 'ID',
    'timezone': 'Asia/Jakarta',
    'sp_code': '51010',
    'X-Child-UID': '',
    'X-PM-Active': 'true',
    'X-Client-Build':
        '1792251581143979383.f54c55ff4034f01d558cfc0cb833288b-1792236719304484383.9f16d590f35f83c81bcfb513645d3703',
    'X-PM-Level': '2',
    'X-Play-Mode': '2',
    'X-Idle-Data': '1',
    'X-Family-Mode': '1',
    'X-Content-Mode': '0',
  });

  static const String _userAgent =
      'com.community.oneroom/50020132 (Linux; U; Android 16; id_ID; Infinix X6870; Build/BP2A.250605.031.A3; Cronet/155.0.8059.16)';

  /// Sort parameter query secara alfabetis sesuai spesifikasi Istio-Envoy Gateway Signer
  static String _formatPathQuery(String pathWithQuery) {
    if (!pathWithQuery.contains('?')) return pathWithQuery;
    final parts = pathWithQuery.split('?');
    final path = parts[0];
    final query = parts.length > 1 ? parts[1] : '';
    if (query.isEmpty) return path;

    final pairs = <MapEntry<String, String>>[];
    for (final part in query.split('&')) {
      if (part.contains('=')) {
        final eqIdx = part.indexOf('=');
        final k = Uri.decodeComponent(part.substring(0, eqIdx));
        final v = Uri.decodeComponent(part.substring(eqIdx + 1));
        pairs.add(MapEntry(k, v));
      } else if (part.isNotEmpty) {
        pairs.add(MapEntry(Uri.decodeComponent(part), ''));
      }
    }
    pairs.sort((a, b) => a.key.compareTo(b.key));
    final sorted = pairs
        .where((e) => e.key.isNotEmpty)
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return sorted.isNotEmpty ? '$path?$sorted' : path;
  }

  /// Hitung signature HMAC-MD5 untuk header x-tr-signature
  static String _generateSignature(
    String method,
    String pathWithQuery, {
    String body = '',
    String accept = '*/*',
    String contentType = '',
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final cl = body.isNotEmpty ? utf8.encode(body).length.toString() : '';
    final bodyMd5 = body.isNotEmpty
        ? md5
            .convert(utf8.encode(body.length > 102400 ? body.substring(0, 102400) : body))
            .toString()
        : '';
    final formattedPath = _formatPathQuery(pathWithQuery);

    final lines = [
      method.toUpperCase(),
      accept,
      contentType,
      cl,
      ts,
      bodyMd5,
      formattedPath,
    ];
    final toSign = lines.join('\n');
    final hmac = Hmac(md5, _gatewaySecret);
    final digest = hmac.convert(utf8.encode(toSign));
    final sig = base64.encode(digest.bytes);
    return '$ts|2|$sig';
  }

  /// Eksekusi request raw HTTP menggunakan HttpClient
  Future<Map<String, dynamic>> _rawRequest(
    String method,
    String pathWithQuery, {
    Map<String, dynamic>? bodyJson,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    client.badCertificateCallback = (cert, host, port) => true;

    try {
      final uri = Uri.parse('$baseUrl$pathWithQuery');
      final bodyStr = bodyJson != null ? jsonEncode(bodyJson) : '';
      final contentType = bodyJson != null ? 'application/json' : '';
      const accept = '*/*';

      final sig = _generateSignature(
        method,
        pathWithQuery,
        body: bodyStr,
        accept: accept,
        contentType: contentType,
      );

      final HttpClientRequest request;
      if (method.toUpperCase() == 'POST') {
        request = await client.postUrl(uri);
      } else {
        request = await client.getUrl(uri);
      }

      request.headers.set('x-tr-signature', sig);
      request.headers.set('authorization', 'Bearer $_authToken');
      request.headers.set('X-Client-Info', _clientInfo);
      request.headers.set('X-Client-Status', '1');
      request.headers.set('user-agent', _userAgent);
      request.headers.set('accept', accept);

      if (contentType.isNotEmpty) {
        request.headers.contentType = ContentType('application', 'json', charset: 'UTF-8');
      }

      if (bodyStr.isNotEmpty) {
        final bodyBytes = utf8.encode(bodyStr);
        request.contentLength = bodyBytes.length;
        request.add(bodyBytes);
      }

      final response = await request.close();
      final resBytes = await response.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      final resText = utf8.decode(resBytes, allowMalformed: true).trim();

      if (response.statusCode == 200 && resText.isNotEmpty) {
        try {
          final parsed = jsonDecode(resText);
          if (parsed is Map<String, dynamic>) {
            return parsed;
          }
        } catch (e) {
          debugPrint('[MovieBoxClient] JSON parse error: $e');
        }
      } else {
        debugPrint(
            '[MovieBoxClient] Request failed (${response.statusCode}) on $pathWithQuery: $resText');
      }
      return {'code': response.statusCode, 'message': 'HTTP ${response.statusCode}', 'data': null};
    } catch (e) {
      debugPrint('[MovieBoxClient] Error on $pathWithQuery: $e');
      return {'code': -1, 'message': '$e', 'data': null};
    } finally {
      client.close(force: true);
    }
  }

  // ==========================================
  // API ENDPOINTS RESMI
  // ==========================================

  /// Ambil daftar Bottom Tabs (Beranda, ShortTV, dll)
  Future<Map<String, dynamic>> fetchBottomTabs() async {
    final resp = await _rawRequest('GET', '/wefeed-mobile-bff/subject-api/bottom-tab');
    if (resp['code'] == 0 && resp['data'] is Map<String, dynamic>) {
      return resp['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// Ambil tab feed / katalog bertingkat (tabId: 0=Home, 13=ShortTV, 2=Film, 5=TV/Serial, 8=Anime)
  Future<Map<String, dynamic>> fetchTabOperating(int tabId, {int page = 1}) async {
    final path = '/wefeed-mobile-bff/tab-operating?page=$page&tabId=$tabId';
    final resp = await _rawRequest('GET', path);
    if (resp['code'] == 0 && resp['data'] is Map<String, dynamic>) {
      return resp['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// Ambil metadata detail Short TV (subjectType: 7)
  Future<Map<String, dynamic>> fetchShortInfo(String subjectId) async {
    final path = '/wefeed-mobile-bff/shorts/get-info?subjectId=$subjectId';
    final resp = await _rawRequest('GET', path);
    if (resp['code'] == 0 && resp['data'] is Map<String, dynamic>) {
      return resp['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// Ambil daftar episode dan URL stream Short TV (maksimal 20 episode per request agar tidak 400)
  Future<List<Map<String, dynamic>>> fetchShortEpisodes(
    String subjectId, {
    int startPosition = 1,
    int endPosition = 20,
  }) async {
    final safeEnd = (endPosition - startPosition >= 20) ? (startPosition + 19) : endPosition;
    final path =
        '/wefeed-mobile-bff/shorts/mini-list?endPosition=$safeEnd&pagerMode=1&startPosition=$startPosition&subjectId=$subjectId';
    final resp = await _rawRequest('GET', path);
    if (resp['code'] == 0 && resp['data'] is Map<String, dynamic>) {
      final items = resp['data']['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }

  /// Ambil metadata detail Film / Serial (subjectType: 1 & 2)
  Future<Map<String, dynamic>> fetchSubjectGet(String subjectId) async {
    final path = '/wefeed-mobile-bff/subject-api/get?subjectId=$subjectId';
    final resp = await _rawRequest('GET', path);
    if (resp['code'] == 0 && resp['data'] is Map<String, dynamic>) {
      return resp['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// Ambil daftar direct stream dan resolusi untuk Film/Serial
  Future<List<Map<String, dynamic>>> fetchPlayInfo(String subjectId) async {
    final path = '/wefeed-mobile-bff/subject-api/play-info?subjectId=$subjectId';
    final resp = await _rawRequest('GET', path);
    if (resp['code'] == 0 && resp['data'] is Map<String, dynamic>) {
      final streams = resp['data']['streams'];
      if (streams is List) {
        return streams.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }

  /// Ambil resources (daftar episode serial, link download/stream, dan subtitle SRT)
  Future<Map<String, dynamic>> fetchSubjectResource(String subjectId) async {
    final path = '/wefeed-mobile-bff/subject-api/resource?subjectId=$subjectId';
    final resp = await _rawRequest('GET', path);
    if (resp['code'] == 0 && resp['data'] is Map<String, dynamic>) {
      return resp['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// Ambil daftar pencarian terpopuler (hot movies, series, shorts, musik)
  Future<List<Map<String, dynamic>>> fetchSearchRank() async {
    final resp = await _rawRequest('GET', '/wefeed-mobile-bff/subject-api/search-rank/v2');
    if (resp['code'] == 0 && resp['data'] is Map<String, dynamic>) {
      final hot = resp['data']['hot'];
      if (hot is List) {
        return hot.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }

  /// Pencarian keyword lintas kategori
  Future<List<Map<String, dynamic>>> search(
    String keyword, {
    int page = 1,
    int perPage = 20,
  }) async {
    final payload = {
      'keyword': keyword,
      'page': page,
      'perPage': perPage,
    };
    final resp = await _rawRequest('POST', '/wefeed-mobile-bff/subject-api/search', bodyJson: payload);
    if (resp['code'] == 0 && resp['data'] is Map<String, dynamic>) {
      final items = resp['data']['items'];
      if (items is List) {
        return items.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }
}
