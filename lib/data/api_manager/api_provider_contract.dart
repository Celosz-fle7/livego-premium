import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';

/// Standard contract every LiveGo provider must satisfy.
///
/// Screen/UI code must not call concrete API clients directly. New APIs should
/// be adapted to this contract so Home/Search/Detail/Player keep the same flow.
abstract class LiveGoApiProviderContract {
  String get platform;
  String get backend;
  LiveGoApiProviderCapability get capability;

  Future<List<ContentItem>> home({required String lang});
  Future<List<ContentItem>> discover({required String lang, int page = 1});
  Future<List<ContentItem>> collection({
    required String collection,
    required String lang,
    int page = 1,
  });

  Future<List<ContentItem>> search({
    required String query,
    required String lang,
  });

  Future<ContentItem?> detail(ContentItem item);
  Future<List<LiveGoEpisode>> episodes(ContentItem item);
  Future<StreamInfo> videoInfo(ContentItem item, {String? chapterId});
  Future<StreamInfo> fastEpisodeStream(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  });

  Future<String> ping(String lang);
}

class LiveGoApiProviderCapability {
  final bool home;
  final bool discover;
  final bool collection;
  final bool search;
  final bool detail;
  final bool episodes;
  final bool video;
  final bool fastVideo;
  final bool subtitle;
  final bool audio;
  final bool encryptedVideo;
  final bool streamFromAllEpisodes;

  const LiveGoApiProviderCapability({
    this.home = true,
    this.discover = true,
    this.collection = true,
    this.search = true,
    this.detail = true,
    this.episodes = true,
    this.video = true,
    this.fastVideo = true,
    this.subtitle = false,
    this.audio = false,
    this.encryptedVideo = false,
    this.streamFromAllEpisodes = false,
  });

  bool supports(ApiProviderFeature feature) {
    switch (feature) {
      case ApiProviderFeature.home:
        return home;
      case ApiProviderFeature.discover:
        return discover;
      case ApiProviderFeature.collection:
        return collection;
      case ApiProviderFeature.search:
        return search;
      case ApiProviderFeature.detail:
        return detail;
      case ApiProviderFeature.episodes:
        return episodes;
      case ApiProviderFeature.video:
        return video;
      case ApiProviderFeature.fastVideo:
        return fastVideo;
      case ApiProviderFeature.subtitle:
        return subtitle;
      case ApiProviderFeature.audio:
        return audio;
    }
  }

  List<String> get badges {
    final result = <String>[];
    if (subtitle) result.add('SUB');
    if (audio) result.add('AUDIO');
    if (encryptedVideo) result.add('DRM');
    if (streamFromAllEpisodes) result.add('ALL-EP');
    return result;
  }
}

enum ApiProviderFeature {
  home,
  discover,
  collection,
  search,
  detail,
  episodes,
  video,
  fastVideo,
  subtitle,
  audio,
}
