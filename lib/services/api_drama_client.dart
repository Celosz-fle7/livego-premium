import '../api/clients/api_http_client.dart';
import '../api/config/api_endpoints.dart';
import '../api/config/api_keys.dart';
import '../api/platforms/platform_registry.dart';
import '../models/content_item.dart';
import '../models/stream_info.dart';

class ApiDramaClient {
  static const String baseUrl = ApiEndpoints.dramaBaseUrl;

  /// Keep the token inside the app while API integration is still being stabilized.
  /// Do not override this from GitHub Actions yet.
  static const String apiSecret = ApiKeys.dramaApiSecret;

  static const String defaultLang = 'id';

  static const List<String> defaultPlatforms = PlatformRegistry.defaultHomePlatforms;
  static const List<String> supportedPlatforms = PlatformRegistry.supportedPlatforms;

  static const ApiHttpClient _client = ApiHttpClient(
    baseUrl: baseUrl,
    secret: apiSecret,
  );

  static Future<List<ContentItem>> home({
    String platform = 'freereels',
    String lang = defaultLang,
  }) async {
    final json = await _client.getJson(ApiEndpoints.home, {
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
    final json = await _client.getJson(ApiEndpoints.discover, {
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
    final json = await _client.getJson(ApiEndpoints.banner, {
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
    final json = await _client.getJson(ApiEndpoints.search, {
      'category_p': platform,
      'q': query.trim(),
      'lang': lang,
      'page': '$page',
    });
    return _parseItems(json, platform: platform, lang: lang);
  }

  static Future<ContentItem?> detail(ContentItem item) async {
    final json = await _client.getJson(ApiEndpoints.detail, {
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
    final json = await _client.getJson(ApiEndpoints.video, {
      'category_p': item.platformSlug,
      'id': item.id,
      'chapterId': chapterId ?? item.chapterId,
      'lang': item.lang,
    });

    final info = StreamInfo.fromApi(json);
    if (info.url.isEmpty) {
      print('LIVEGO STREAM WARNING => empty url for ${item.platformSlug}/${item.id}/${chapterId ?? item.chapterId}');
    }
    return info;
  }

  static Future<String> videoUrl(ContentItem item, {String chapterId = '1'}) async {
    final info = await videoInfo(item, chapterId: chapterId);
    return info.url;
  }

  static Future<List<String>> categories() async {
    final json = await _client.getJson(ApiEndpoints.categories, {});
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

  static Future<List<String>> languages() async {
    final json = await _client.getJson(ApiEndpoints.languages, {});
    final data = json['data'];
    if (data is List) {
      return data
          .map((e) {
            if (e is Map) return '${e['code'] ?? e['name'] ?? ''}';
            return '$e';
          })
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const ['id'];
  }

  static List<ContentItem> _parseItems(
    Map<String, dynamic> json, {
    required String platform,
    required String lang,
  }) {
    final data = json['data'];
    if (data is! List) {
      print('LIVEGO PARSE WARNING => data is not List for $platform: ${data.runtimeType}');
      return [];
    }

    return data
        .whereType<Map>()
        .map((e) => ContentItem.fromApi(Map<String, dynamic>.from(e), platformSlug: platform, lang: lang))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }
}
