import '../models/content_item.dart';
import '../models/livego_episode.dart';
import '../models/stream_info.dart';
import 'nobuzero/nobuzero_api_client_impl.dart';

/// Public Nobuzero API facade.
class NobuzeroApiClient {
  const NobuzeroApiClient._();

  static String get baseUrl => NobuzeroApiClientImpl.baseUrl;

  static Future<List<String>> languages() => NobuzeroApiClientImpl.languages();
  static Future<List<String>> categories() => NobuzeroApiClientImpl.categories();
  static Future<Map<String, dynamic>> keyStatus() => NobuzeroApiClientImpl.keyStatus();

  static Future<List<ContentItem>> home({
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
  }) =>
      NobuzeroApiClientImpl.home(platform: platform, lang: lang);

  static Future<List<ContentItem>> discover({
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      NobuzeroApiClientImpl.discover(platform: platform, lang: lang, page: page);

  static Future<List<ContentItem>> collection({
    String platform = 'nobuzero_shortmax',
    required String collection,
    String lang = 'id',
    int page = 1,
  }) =>
      NobuzeroApiClientImpl.collection(
        platform: platform,
        collection: collection,
        lang: lang,
        page: page,
      );

  static Future<List<ContentItem>> homeFeed({
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      NobuzeroApiClientImpl.homeFeed(platform: platform, lang: lang, page: page);

  static Future<List<ContentItem>> liveGoFeed({
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      NobuzeroApiClientImpl.liveGoFeed(platform: platform, lang: lang, page: page);

  static Future<List<ContentItem>> indonesiaFeed({
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      NobuzeroApiClientImpl.indonesiaFeed(platform: platform, lang: lang, page: page);

  static Future<List<ContentItem>> banner({
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
  }) =>
      NobuzeroApiClientImpl.banner(platform: platform, lang: lang);

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'nobuzero_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      NobuzeroApiClientImpl.search(query: query, platform: platform, lang: lang, page: page);

  static Future<ContentItem?> detail(ContentItem item) =>
      NobuzeroApiClientImpl.detail(item);

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) =>
      NobuzeroApiClientImpl.episodes(item);

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) =>
      NobuzeroApiClientImpl.videoInfo(item, chapterId: chapterId);

  static Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) =>
      NobuzeroApiClientImpl.fastEpisodeStream(item, chapterId: chapterId, timeout: timeout);

  static Future<String> ping(String platform, String lang) =>
      NobuzeroApiClientImpl.ping(platform, lang);
}
