import '../models/livego_content.dart';
import '../models/livego_detail.dart';
import '../models/livego_stream.dart';
import 'livego_api_client.dart';
import 'livego_source_state.dart';

class LiveGoRepository {
  static const String defaultLang = 'id';

  static Future<List<LiveGoContent>> banner({
    String? platform,
    String lang = defaultLang,
  }) async {
    return _list(
      path: '/api/v2/banner',
      platform: platform ?? LiveGoSourceState.enabledSlugs.first,
      lang: lang,
    );
  }

  static Future<List<LiveGoContent>> home({
    String? platform,
    String lang = defaultLang,
  }) async {
    return _list(
      path: '/api/v2/home',
      platform: platform ?? LiveGoSourceState.enabledSlugs.first,
      lang: lang,
    );
  }

  static Future<List<LiveGoContent>> discover({
    String? platform,
    String lang = defaultLang,
    int page = 1,
  }) async {
    return _list(
      path: '/api/v2/discover',
      platform: platform ?? LiveGoSourceState.enabledSlugs.first,
      lang: lang,
      extra: {
        'page': '$page',
      },
    );
  }

  static Future<List<LiveGoContent>> search({
    required String query,
    String? platform,
    String lang = defaultLang,
    int page = 1,
  }) async {
    return _list(
      path: '/api/v2/search',
      platform: platform ?? LiveGoSourceState.enabledSlugs.first,
      lang: lang,
      extra: {
        'q': query,
        'page': '$page',
      },
    );
  }

  static Future<LiveGoDetail> detail({
    required String id,
    required String platform,
    String lang = defaultLang,
  }) async {
    final json = await LiveGoApiClient.get(
      '/api/v2/detail',
      query: {
        'category_p': platform,
        'id': id,
        'lang': lang,
      },
      signed: true,
    );

    return LiveGoDetail.fromJson(
      json,
      platform: platform,
    );
  }

  static Future<LiveGoStream> video({
    required String id,
    required String platform,
    required String chapterId,
    String lang = defaultLang,
  }) async {
    final json = await LiveGoApiClient.get(
      '/api/v2/video',
      query: {
        'category_p': platform,
        'id': id,
        'chapterId': chapterId,
        'lang': lang,
      },
      signed: true,
    );

    return LiveGoStream.fromJson(json);
  }

  static Future<List<LiveGoContent>> _list({
    required String path,
    required String platform,
    required String lang,
    Map<String, String> extra = const {},
  }) async {
    final json = await LiveGoApiClient.get(
      path,
      query: {
        'category_p': platform,
        'lang': lang,
        ...extra,
      },
      signed: true,
    );

    final raw = json['data'];

    if (raw is! List) {
      return const <LiveGoContent>[];
    }

    return raw.map((e) {
      return LiveGoContent.fromJson(
        Map<String, dynamic>.from(e),
        platform: '${json['platform'] ?? platform}',
      );
    }).toList();
  }
}
