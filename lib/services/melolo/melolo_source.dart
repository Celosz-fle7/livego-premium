import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'melolo_client.dart';
import 'melolo_config.dart';

/// Adapter Melolo sebagai DramaSource di LiveGo.
/// Menghubungkan kategori asli Melolo dan API resmi ke UI Mobile & TV.
class MeloloSource implements DramaSource {
  final MeloloClient _client = MeloloClient();

  /// Cache stream URL per "$seriesId:$episodeId"
  final Map<String, String> _streamCache = {};

  MeloloClient get client => _client;

  @override
  String get slug => 'melolo';

  @override
  String get label => 'Melolo';

  @override
  List<String> get categories => MeloloConfig.categories;

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

  /// Melolo memakai identitas perangkat (kredensial di config), bukan
  /// sesi akun — tidak ada yang perlu keluar. Penolakan server
  /// (risk control) dilempar sebagai MeloloAuthException di client.
  @override
  Future<void> signOut() async {}
}
