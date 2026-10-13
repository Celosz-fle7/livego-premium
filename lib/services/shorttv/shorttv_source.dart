import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'shorttv_client.dart';
import 'shorttv_config.dart';

/// Adapter ShortTV sebagai DramaSource di LiveGo.
/// Menghubungkan discovery multi-bahasa, daftar episode, dan stream HLS AES-128 terdekripsi
/// langsung ke player UI Mobile & TV tanpa aplikasi latar belakang.
class ShortTvSource implements DramaSource {
  final ShortTvClient _client = ShortTvClient.instance;

  /// Cache stream URL per "$seriesId:$episodeId:$quality"
  final Map<String, String> _streamCache = {};

  ShortTvClient get client => _client;

  @override
  String get slug => 'shorttv';

  @override
  String get label => 'ShortTV';

  @override
  List<String> get categories => ShortTvConfig.categories;

  @override
  Future<List<ContentItem>> homeByCategory(String category) {
    return _client.feedForCategory(category);
  }

  @override
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) {
    return _client.feedPage(category, page: page, pageSize: pageSize);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) {
    return _client.episodeList(seriesId);
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final cacheKey = '$seriesId:$episodeId:${quality ?? 'auto'}';
    final cached = _streamCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    final url = await _client.streamUrl(
      seriesId: seriesId,
      episodeId: episodeId,
      quality: quality,
    );
    if (url.isNotEmpty) {
      _streamCache[cacheKey] = url;
    }
    return url;
  }

  @override
  Future<List<ContentItem>> search(String query) {
    return _client.search(query);
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) {
    return _client.episodeExtras(seriesId, episodeId);
  }

  @override
  Future<void> signOut() async {
    ShortTvClient.instance.signOut();
    _streamCache.clear();
  }
}
