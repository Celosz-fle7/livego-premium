class ApiDramaClient {
  static const String baseUrl = ApiConfig.baseUrl;
  static const String apiSecret = ApiConfig.apiSecret;
  static const String defaultLang = ApiConfig.defaultLang;

  static const List<String> defaultPlatforms = PlatformRegistry.defaultPlatforms;
  static const List<String> supportedPlatforms = PlatformRegistry.supportedPlatforms;

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

    final request = await HttpClient().getUrl(uri).timeout(ApiConfig.timeout);
    final headers = <String, String>{
      ...ApiConfig.defaultHeaders,
      ...const HmacSigner(apiSecret).sign('GET', uri),
    };

    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }

    final response = await request.close().timeout(ApiConfig.timeout);
    final body = await response.transform(utf8.decoder).join();
    final preview = body.length > 240 ? body.substring(0, 240) : body;
    print('LIVEGO API <= ${response.statusCode} $preview');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('API ${response.statusCode}: $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }
}
