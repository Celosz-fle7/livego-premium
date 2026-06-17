import '../models/content_item.dart';
import '../models/livego_episode.dart';
import '../models/stream_info.dart';
import 'api/api_platform.dart';
import 'nobuzero_api_client.dart';

class LiveGoApiGateway {
  const LiveGoApiGateway._();

  static List<String> get supportedPlatforms => LiveGoApiPlatforms.supportedSlugs;
  static List<String> get defaultPlatforms => LiveGoApiPlatforms.defaultSlugs;

  static bool supports(String platform) => LiveGoApiPlatforms.supports(platform);

  /// API aktif TV sekarang sengaja satu pintu: Nobuzero.
  static bool isNobuzero(String platform) => true;

  static Future<List<String>> languages() => NobuzeroApiClient.languages();
  static Future<List<String>> categories() => NobuzeroApiClient.categories();
  static Future<Map<String, dynamic>> keyStatus() => NobuzeroApiClient.keyStatus();

  static Future<List<ContentItem>> home({
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
  }) {
    return NobuzeroApiClient.home(platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> discover({
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
    int page = 1,
  }) {
    return NobuzeroApiClient.discover(platform: platform, lang: lang, page: page);
  }

  static Future<List<ContentItem>> collection({
    String platform = 'nobuzero_shortmax',
    required String collection,
    String lang = 'id',
    int page = 1,
  }) {
    return NobuzeroApiClient.collection(
      platform: platform,
      collection: collection,
      lang: lang,
      page: page,
    );
  }

  static Future<List<ContentItem>> banner({
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
  }) {
    return NobuzeroApiClient.banner(platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
  }) {
    return NobuzeroApiClient.search(query: query, platform: platform, lang: lang);
  }

  static Future<ContentItem?> detail(ContentItem item) {
    return NobuzeroApiClient.detail(item);
  }

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) {
    return NobuzeroApiClient.episodes(item);
  }

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) {
    return NobuzeroApiClient.videoInfo(item, chapterId: chapterId);
  }

  static Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) {
    return NobuzeroApiClient.fastEpisodeStream(item, chapterId: chapterId, timeout: timeout);
  }

  static Future<String> ping(String platform, String lang) {
    return NobuzeroApiClient.ping(platform, lang);
  }
}
