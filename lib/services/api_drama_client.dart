import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/content_item.dart';
import '../models/stream_info.dart';

class ApiDramaClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-drama.dobda.id',
  );

  // Development hardcoded secret.
  // Jangan pakai String.fromEnvironment untuk sementara, karena workflow lama bisa mengirim
  // API_SECRET kosong dan menimpa fallback sehingga request tidak signed.
  static const String apiSecret =
      '22dfb2b849814054af0491ff2ee3ffe33989313d7d38e97aae659757a4cf8960';

  static const String defaultLang = String.fromEnvironment(
    'API_LANG',
    defaultValue: 'id',
  );

  static const List<String> defaultPlatforms = [
    'freereels',
    'goodshort',
    'dramawave',
    'netshort',
    'reelshort',
    'melolo',
  ];

  static const List<String> supportedPlatforms = [
    'freereels',
    'goodshort',
    'dramawave',
    'netshort',
    'reelshort',
    'reelife',
    'rapidtv',
    'flickreels',
    'dramapops',
    'dramapoops',
    'shortmax',
    'dramanova',
    'dramarush',
    'melolo',
    'starshort',
    'meloshort',
    'dramabite',
    'stardusttv',
    'dramabox',
    'drachin',
    'youku',
    'tencent',
    'iqiyi',
    'mango',
    'wetv',
    'viki',
    'shorttv',
    'minidrama',
    'topreels',
    'moboreels',
    'flexreels',
    'livego',
  ];

  static Future<List<ContentItem>> home({
    String platform = 'freereels',
    String lang = defaultLang,
  }) async {
    final json = await _getJson('/api/v2/home', {
      'category_p': platform,
      'lang': lang,
    });
    return _parseItems(json, platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> discover({
    String platform = 'freereels',
    String lang = defaultLang,
    int page = 1,
  }) async {
    final json = await _getJson('/api/v2/discover', {
      'category_p': platform,
      'lang': lang,
      'page': '$page',
    });
    return _parseItems(json, platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> banner({
    String platform = 'freereels',
    String lang = defaultLang,
  }) async {
    final json = await _getJson('/api/v2/banner', {
      'category_p': platform,
      'lang': lang,
    });
    return _parseItems(json, platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'freereels',
    String lang = defaultLang,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return [];
    final json = await _getJson('/api/v2/search', {
      'category_p': platform,
      'q': query.trim(),
      'lang': lang,
      'page': '$page',
    });
    return _parseItems(json, platform: platform, lang: lang);
  }

  static Future<ContentItem?> detail(ContentItem item) async {
    final json = await _getJson('/api/v2/detail', {
      'category_p': item.platformSlug,
      'id': item.id,
      'lang': item.lang,
    });

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return ContentItem.fromApi(data, platformSlug: item.platformSlug, lang: item.lang);
    }
    if (data is Map) {
      return ContentItem.fromApi(Map<String, dynamic>.from(data), platformSlug: item.platformSlug, lang: item.lang);
    }
    return null;
  }

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) async {
    final json = await _getJson('/api/v2/video', {
      'category_p': item.platformSlug,
      'id': item.id,
      'chapterId': chapterId ?? item.chapterId,
      'lang': item.lang,
    });
    return StreamInfo.fromApi(json);
  }

  static Future<String> videoUrl(ContentItem item, {String chapterId = '1'}) async {
    final info = await videoInfo(item, chapterId: chapterId);
    return info.url;
  }

  static Future<List<String>> categories() async {
    final json = await _getJson('/api/v2/categories', {});
    final data = json['data'];
    if (data is List) {
      return data
          .map((e) {
            if (e is Map) return '${e['name'] ?? e['display_name'] ?? ''}';
            return '$e';
          })
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return defaultPlatforms;
  }

  static List<ContentItem> _parseItems(
    Map<String, dynamic> json, {
    required String platform,
    required String lang,
  }) {
    final data = json['data'];
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((e) => ContentItem.fromApi(Map<String, dynamic>.from(e), platformSlug: platform, lang: lang))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  static Future<Map<String, dynamic>> _getJson(String path, Map<String, String> query) async {
    final uri = Uri.parse(baseUrl).replace(path: path, queryParameters: query.isEmpty ? null : query);
    print('LIVEGO API => GET $uri');

    final request = await HttpClient().getUrl(uri).timeout(const Duration(seconds: 18));

    for (final entry in _signedHeaders('GET', uri).entries) {
      request.headers.set(entry.key, entry.value);
    }

    final response = await request.close().timeout(const Duration(seconds: 18));
    final body = await response.transform(utf8.decoder).join();
    print('LIVEGO API <= ${response.statusCode} ${body.length > 220 ? body.substring(0, 220) : body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  static Map<String, String> _signedHeaders(String method, Uri uri) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final pathWithQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final headers = <String, String>{'Accept': 'application/json'};

    if (apiSecret.isNotEmpty) {
      final payload = '$method:$pathWithQuery:$timestamp';
      final signature = Hmac(sha256, utf8.encode(apiSecret)).convert(utf8.encode(payload)).toString();
      headers['X-Timestamp'] = timestamp;
      headers['X-Signature'] = signature;
    }

    return headers;
  }
}
