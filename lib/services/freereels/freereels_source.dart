import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'freereels_client.dart';
import 'freereels_config.dart';

/// Adapter FreeReels sebagai DramaSource.
///
/// Meniru 100% perilaku APK: kategori = tab bawaan APK,
/// home = GET /frv2-api/homepage/v2/tab/index per tab_key.
class FreereelsSource implements DramaSource {
  final FreereelsClient _client = FreereelsClient();

  @override
  String get slug => 'freereels';

  @override
  String get label => 'FreeReels';

  @override
  List<String> get categories => FreereelsConfig.tabKeys.keys.toList(growable: false);

  @override
  Future<List<ContentItem>> homeByCategory(String category) {
    final tabKey =
        FreereelsConfig.tabKeys[category] ?? FreereelsConfig.tabKeys['Popular']!;
    return _client.tabFeed(tabKey: tabKey, category: category);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) {
    // TODO: isi setelah format endpoint episode diketahui
    // Kandidat: GET /frv2-api/drama/info_v2 / /frv2-api/advertise/series/resolve
    throw UnimplementedError('FreereelsSource.episodes belum diimplementasi');
  }

  @override
  Future<String> streamUrl({required String seriesId, required String episodeId}) {
    // TODO: isi setelah format endpoint stream diketahui
    // Kandidat: GET /frv2-api/getplayinfo/v4
    throw UnimplementedError('FreereelsSource.streamUrl belum diimplementasi');
  }
}
