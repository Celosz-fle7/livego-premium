import '../models/content_item.dart';
import '../models/livego_episode.dart';
import '../models/stream_info.dart';
import 'api/api_platform.dart';
import 'dobda_api_client.dart';

class LiveGoApiGateway {
  const LiveGoApiGateway._();

  static List<String> get supportedPlatforms => LiveGoApiPlatforms.supportedSlugs;
  static List<String> get defaultPlatforms => LiveGoApiPlatforms.defaultSlugs;

  static bool supports(String platform) => LiveGoApiPlatforms.supports(platform);

  /// API aktif TV sekarang sengaja satu pintu: Dobda.
  ///
  /// Platform lama/Anichin sudah dibackup di branch backup/api-before-clean dan
  /// tidak dipakai lagi di jalur Home/Player supaya management API tidak ruwet.
  static bool isDobda(String platform) => true;

  static Future<List<ContentItem>> home({
    String platform = 'melolo',
    String lang = 'id',
  }) {
    return DobdaApiClient.home(platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> discover({
    String platform = 'melolo',
    String lang = 'id',
    int page = 1,
  }) {
    return DobdaApiClient.discover(platform: platform, lang: lang, page: page);
  }

  static Future<List<ContentItem>> collection({
    String platform = 'melolo',
    required String collection,
    String lang = 'id',
    int page = 1,
  }) {
    return DobdaApiClient.collection(
      platform: platform,
      collection: collection,
      lang: lang,
      page: page,
    );
  }

  static Future<List<ContentItem>> banner({
    String platform = 'melolo',
    String lang = 'id',
  }) {
    return DobdaApiClient.banner(platform: platform, lang: lang);
  }

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'melolo',
    String lang = 'id',
  }) {
    return DobdaApiClient.search(query: query, platform: platform, lang: lang);
  }

  static Future<ContentItem?> detail(ContentItem item) {
    return DobdaApiClient.detail(item);
  }

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) {
    return DobdaApiClient.episodes(item);
  }

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) {
    return DobdaApiClient.videoInfo(item, chapterId: chapterId);
  }

  static Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) {
    return DobdaApiClient.fastEpisodeStream(item, chapterId: chapterId, timeout: timeout);
  }

  static Future<String> ping(String platform, String lang) {
    return DobdaApiClient.ping(platform, lang);
  }
}
