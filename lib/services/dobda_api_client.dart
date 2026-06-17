import '../models/content_item.dart';
import '../models/livego_episode.dart';
import '../models/stream_info.dart';
import 'dobda/dobda_api_client_impl.dart';

/// Public Dobda API facade.
class DobdaApiClient {
  const DobdaApiClient._();

  static String get baseUrl => DobdaApiClientImpl.baseUrl;

  static Future<List<String>> languages() => DobdaApiClientImpl.languages();
  static Future<List<String>> categories() => DobdaApiClientImpl.categories();
  static Future<Map<String, dynamic>> keyStatus() => DobdaApiClientImpl.keyStatus();

  static Future<List<ContentItem>> home({
    String platform = 'dobda_shortmax',
    String lang = 'id',
  }) =>
      DobdaApiClientImpl.home(platform: platform, lang: lang);

  static Future<List<ContentItem>> discover({
    String platform = 'dobda_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      DobdaApiClientImpl.discover(platform: platform, lang: lang, page: page);

  static Future<List<ContentItem>> collection({
    String platform = 'dobda_shortmax',
    required String collection,
    String lang = 'id',
    int page = 1,
  }) =>
      DobdaApiClientImpl.collection(
        platform: platform,
        collection: collection,
        lang: lang,
        page: page,
      );

  static Future<List<ContentItem>> homeFeed({
    String platform = 'dobda_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      DobdaApiClientImpl.homeFeed(platform: platform, lang: lang, page: page);

  static Future<List<ContentItem>> liveGoFeed({
    String platform = 'dobda_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      DobdaApiClientImpl.liveGoFeed(platform: platform, lang: lang, page: page);

  static Future<List<ContentItem>> indonesiaFeed({
    String platform = 'dobda_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      DobdaApiClientImpl.indonesiaFeed(platform: platform, lang: lang, page: page);

  static Future<List<ContentItem>> banner({
    String platform = 'dobda_shortmax',
    String lang = 'id',
  }) =>
      DobdaApiClientImpl.banner(platform: platform, lang: lang);

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'dobda_shortmax',
    String lang = 'id',
    int page = 1,
  }) =>
      DobdaApiClientImpl.search(query: query, platform: platform, lang: lang, page: page);

  static Future<ContentItem?> detail(ContentItem item) =>
      DobdaApiClientImpl.detail(item);

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) =>
      DobdaApiClientImpl.episodes(item);

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) =>
      DobdaApiClientImpl.videoInfo(item, chapterId: chapterId);

  static Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) =>
      DobdaApiClientImpl.fastEpisodeStream(item, chapterId: chapterId, timeout: timeout);

  static Future<String> ping(String platform, String lang) =>
      DobdaApiClientImpl.ping(platform, lang);
}
