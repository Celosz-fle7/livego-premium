import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';
import '../../services/api/api_backend.dart';
import '../../services/api/api_platform.dart';
import '../../services/livego_api_gateway.dart';
import 'api_provider_contract.dart';

class LiveGoApiProviderRegistry {
  const LiveGoApiProviderRegistry._();

  static LiveGoApiProviderContract providerFor(String platform) {
    final config = LiveGoApiPlatforms.bySlug(platform);
    return _GatewayApiProvider(config);
  }

  static LiveGoApiProviderCapability capabilityFor(String platform) {
    return providerFor(platform).capability;
  }

  static bool supports(String platform, ApiProviderFeature feature) {
    return capabilityFor(platform).supports(feature);
  }

  static List<String> capabilityBadgesFor(String platform) {
    return capabilityFor(platform).badges;
  }
}

class _GatewayApiProvider implements LiveGoApiProviderContract {
  final LiveGoApiPlatform config;

  const _GatewayApiProvider(this.config);

  @override
  String get platform => config.slug;

  @override
  String get backend => config.backend.label;

  @override
  LiveGoApiProviderCapability get capability => LiveGoApiProviderCapability(
        home: true,
        discover: true,
        collection: true,
        search: true,
        detail: true,
        episodes: true,
        video: config.videoType != LiveGoVideoType.encrypted,
        fastVideo: config.videoType != LiveGoVideoType.encrypted,
        subtitle: config.supportsSubtitle,
        audio: false,
        encryptedVideo: config.videoType == LiveGoVideoType.encrypted,
        streamFromAllEpisodes: config.streamFromAllEpisodes,
      );

  @override
  Future<List<ContentItem>> home({required String lang}) {
    return LiveGoApiGateway.home(platform: platform, lang: lang);
  }

  @override
  Future<List<ContentItem>> discover({required String lang, int page = 1}) {
    return LiveGoApiGateway.discover(platform: platform, lang: lang, page: page);
  }

  @override
  Future<List<ContentItem>> collection({
    required String collection,
    required String lang,
    int page = 1,
  }) {
    return LiveGoApiGateway.collection(
      platform: platform,
      collection: collection,
      lang: lang,
      page: page,
    );
  }

  @override
  Future<List<ContentItem>> search({
    required String query,
    required String lang,
  }) {
    return LiveGoApiGateway.search(query: query, platform: platform, lang: lang);
  }

  @override
  Future<ContentItem?> detail(ContentItem item) {
    return LiveGoApiGateway.detail(item);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(ContentItem item) {
    return LiveGoApiGateway.episodes(item);
  }

  @override
  Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId}) {
    return LiveGoApiGateway.videoInfo(item, chapterId: chapterId);
  }

  @override
  Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) {
    return LiveGoApiGateway.fastEpisodeStream(item, chapterId: chapterId, timeout: timeout);
  }

  @override
  Future<String> ping(String lang) {
    return LiveGoApiGateway.ping(platform, lang);
  }
}
