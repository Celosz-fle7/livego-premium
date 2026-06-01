import '../models/content_item.dart';
import '../models/livego_episode.dart';
import '../models/stream_info.dart';
import 'anichin_api_client.dart';
import 'api/api_backend.dart';
import 'api/api_platform.dart';
import 'dobda_api_client.dart';

class LiveGoApiGateway {
  const LiveGoApiGateway._();

  static List<String> get supportedPlatforms => LiveGoApiPlatforms.supportedSlugs;
  static List<String> get defaultPlatforms => LiveGoApiPlatforms.defaultSlugs;

  static bool supports(String platform) => LiveGoApiPlatforms.supports(platform);

  static bool isDobda(String platform) =>
      LiveGoApiPlatforms.backendOf(platform) == LiveGoApiBackend.dobda;

  static Future<List<ContentItem>> home({
    String platform = 'shortmax',
    String lang = 'id',
  }) {
    if (isDobda(platform)) return DobdaApiClient.home(platform: platform, lang: lang);
    return AnichinApiClient.home(platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> discover({
    String platform = 'shortmax',
    String lang = 'id',
    int page = 1,
  }) {
    if (isDobda(platform)) return DobdaApiClient.discover(platform: platform, lang: lang, page: page);
    return AnichinApiClient.discover(platform: platform, lang: lang, page: page);
  }

  static Future<List<ContentItem>> collection({
    String platform = 'shortmax',
    required String collection,
    String lang = 'id',
    int page = 1,
  }) {
    if (isDobda(platform)) {
      return DobdaApiClient.collection(
        platform: platform,
        collection: collection,
        lang: lang,
        page: page,
      );
    }
    return AnichinApiClient.collection(
      platform: platform,
      collection: collection,
      lang: lang,
      page: page,
    );
  }

  static Future<List<ContentItem>> banner({
    String platform = 'shortmax',
    String lang = 'id',
  }) {
    if (isDobda(platform)) return DobdaApiClient.banner(platform: platform, lang: lang);
    return AnichinApiClient.banner(platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'shortmax',
    String lang = 'id',
  }) {
    if (isDobda(platform)) {
      return DobdaApiClient.search(query: query, platform: platform, lang: lang);
    }
    return AnichinApiClient.search(query: query, platform: platform, lang: lang);
  }

  static Future<ContentItem?> detail(ContentItem item) {
    if (isDobda(item.platformSlug)) return DobdaApiClient.detail(item);
    return AnichinApiClient.detail(item);
  }

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) {
    if (isDobda(item.platformSlug)) return DobdaApiClient.episodes(item);
    return AnichinApiClient.episodes(item);
  }

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) {
    if (isDobda(item.platformSlug)) return DobdaApiClient.videoInfo(item, chapterId: chapterId);
    return AnichinApiClient.videoInfo(item, chapterId: chapterId);
  }

  static Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) {
    if (isDobda(item.platformSlug)) {
      return DobdaApiClient.fastEpisodeStream(item, chapterId: chapterId, timeout: timeout);
    }
    return AnichinApiClient.fastEpisodeStream(item, chapterId: chapterId, timeout: timeout);
  }

  static Future<String> ping(String platform, String lang) async {
    if (isDobda(platform)) return DobdaApiClient.ping(platform, lang);
    final start = DateTime.now();
    final rows = await AnichinApiClient.home(platform: platform, lang: lang);
    if (rows.isEmpty) return 'offline';
    final ms = DateTime.now().difference(start).inMilliseconds;
    return ms > 2500 ? 'slow' : 'online';
  }
}
