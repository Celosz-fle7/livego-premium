import '../models/content_item.dart';
import '../models/livego_episode.dart';
import '../models/stream_info.dart';
import 'api/api_platform.dart';

class LiveGoApiGateway {
  const LiveGoApiGateway._();

  static List<String> get supportedPlatforms => LiveGoApiPlatforms.supportedSlugs;
  static List<String> get defaultPlatforms => LiveGoApiPlatforms.defaultSlugs;

  static bool supports(String platform) => LiveGoApiPlatforms.supports(platform);

  static bool isDobda(String platform) => false;

  static Future<List<ContentItem>> home({
    String platform = 'melolo',
    String lang = 'id',
  }) async => const [];

  static Future<List<ContentItem>> discover({
    String platform = 'melolo',
    String lang = 'id',
    int page = 1,
  }) async => const [];

  static Future<List<ContentItem>> collection({
    String platform = 'melolo',
    required String collection,
    String lang = 'id',
    int page = 1,
  }) async => const [];

  static Future<Map<String, List<String>>> categories({
    String platform = 'melolo',
    String lang = 'id',
  }) async => const {};

  static Future<List<ContentItem>> banner({
    String platform = 'melolo',
    String lang = 'id',
  }) async => const [];

  static Future<List<ContentItem>> search({
    required String query,
    String platform = 'melolo',
    String lang = 'id',
  }) async => const [];

  static Future<ContentItem?> detail(ContentItem item) async => null;

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) async => const [];

  static Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) async =>
      StreamInfo.empty;

  static Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) async =>
      StreamInfo.empty;

  static Future<String> ping(String platform, String lang) async => 'pong';
}
