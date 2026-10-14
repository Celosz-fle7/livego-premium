import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'shortdramatv_client.dart';
import 'shortdramatv_config.dart';

/// Adapter ShortDramaTV sebagai DramaSource di LiveGo.
///
/// ShortDramaTV (com.shortdramatv.rlles) menggunakan:
/// - Video CDN: bxdgpro.hfbjz.top (direct MP4, bukan HLS)
/// - Local proxy: 127.0.0.1:7000/resource.mp4?src={base64}
/// - API endpoints terenkripsi di SigL360 native lib
///
/// Implementasi ini fokus pada:
/// 1. Play video dari CDN langsung (via local proxy)
/// 2. Browse dari cached local data
/// 3. Stream proxy dengan Range request support
class ShortDramaTvSource implements DramaSource {
  final ShortDramaTvClient _client = ShortDramaTvClient.instance;

  // Cache stream URL per "$seriesId:$episodeId"
  final Map<String, String> _streamCache = {};

  // Seed data dari local DB (diisi oleh repository saat init)
  List<ContentItem> _seedItems = [];

  ShortDramaTvClient get client => _client;

  @override
  String get slug => 'shortdramatv';

  @override
  String get label => 'ShortDramaTV';

  @override
  List<String> get categories => ShortDramaTvConfig.categories;

  /// Set seed items dari local DB (look_history + spUtils cache)
  void setSeedItems(List<ContentItem> items) {
    _seedItems = items;
  }

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    if (_seedItems.isNotEmpty) {
      return _seedItems.where((item) => item.category == category || category == 'Semua').toList();
    }
    return _client.feedForCategory(category);
  }

  @override
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final items = await homeByCategory(category);
    return (items: items, hasMore: false);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    // seriesId bisa berupa vod_id atau series hash
    // Kalau dari seed data, kita perlu lookup total episodes
    // Untuk sekarang, return empty - akan diisi dari detail API nanti
    return const [];
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final cacheKey = '$seriesId:$episodeId';
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
  Future<List<ContentItem>> search(String query) async {
    return _client.search(query);
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(String seriesId, String episodeId) async {
    return _client.episodeExtras(seriesId, episodeId);
  }

  @override
  Future<void> signOut() async {
    _client.signOut();
    _streamCache.clear();
  }
}
