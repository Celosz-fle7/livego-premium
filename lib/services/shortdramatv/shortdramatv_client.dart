import 'dart:convert';
import 'dart:io';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'shortdramatv_config.dart';
import 'shortdramatv_stream_proxy.dart';

/// HTTP Client untuk ShortDramaTV API.
///
/// CATATAN: API endpoint paths terenkripsi di SigL360 native lib.
/// Implementasi ini menggunakan:
/// 1. Direct CDN URL pattern (bxdgpro.hfbjz.top) untuk streaming
/// 2. Cached data dari local DB (look_history, spUtils) untuk browse
/// 3. Local proxy untuk video streaming
class ShortDramaTvClient {
  static ShortDramaTvClient? _instance;
  static ShortDramaTvClient get instance => _instance ??= ShortDramaTvClient._();

  ShortDramaTvClient._();

  String _token = ShortDramaTvConfig.defaultToken;
  DateTime? _tokenExpiry;

  bool get hasSession => _token.isNotEmpty;

  void signOut() {
    _token = '';
    _tokenExpiry = null;
  }

  /// Seed data dari local DB (look_history + spUtils cache).
  /// Ini adalah data yang sudah ter-cache dari interaksi user sebelumnya.
  List<ContentItem> seedFromLocalData(List<Map<String, dynamic>> historyEntries) {
    final items = <ContentItem>[];

    for (final entry in historyEntries) {
      final id = '${entry['id'] ?? ''}';
      if (id.isEmpty) continue;

      final title = '${entry['vod_name'] ?? 'Untitled'}';
      final pic = '${entry['vod_pic'] ?? ''}';
      final serial = entry['vod_serial'] ?? 0;
      final total = entry['vod_total'] ?? 0;
      final theme = '${entry['theme'] ?? ''}';
      final viewCount = entry['view_count'] ?? 0;

      items.add(ContentItem(
        id: id,
        title: title,
        source: 'shortdramatv',
        category: 'Trending',
        description: theme,
        posterUrl: pic,
        backdropUrl: pic,
        rating: 8.5,
        episodes: total is int && total > 0 ? total : (serial is int && serial > 0 ? serial : 1),
        platformSlug: 'shortdramatv',
        lang: 'id',
        tags: theme.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      ));
    }

    return items;
  }

  /// Coba fetch feed dari API. Karena endpoint encrypted, ini fallback ke seed data.
  Future<List<ContentItem>> feedForCategory(String category) async {
    // TODO: Implementasi API call setelah endpoint paths ter-decode
    // Untuk sekarang, return empty (akan diisi dari local DB oleh source)
    return const [];
  }

  Future<List<ContentItem>> search(String keyword) async {
    // TODO: Implementasi search API
    return const [];
  }

  /// Ambil daftar episode. Karena API encrypted, gunakan pattern dari URL.
  /// Episode bisa di-derive dari total episodes di metadata.
  Future<List<LiveGoEpisode>> episodeList(String seriesId, {int totalEps = 1}) async {
    final episodes = <LiveGoEpisode>[];
    for (var i = 1; i <= totalEps; i++) {
      episodes.add(LiveGoEpisode(
        id: '$i',
        index: i,
        title: 'Episode $i',
      ));
    }
    return episodes;
  }

  /// Ambil stream URL episode.
  /// Menggunakan direct CDN URL + local proxy.
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final ep = int.tryParse(episodeId) ?? 1;

    // seriesId di sini adalah series hash (bukan vod_id)
    // Contoh: '1beb86b99ef31eb6'
    final directUrl = ShortDramaTvConfig.videoUrl(seriesId, ep);

    // Wrap ke local proxy
    return ShortDramaTvStreamProxy.instance.wrapUrl(directUrl);
  }

  Future<DramaEpisodeExtras?> episodeExtras(String seriesId, String episodeId) async {
    return DramaEpisodeExtras(
      qualities: const [
        DramaQuality(label: '1080p', resolution: '1080x1920 (FHD)'),
        DramaQuality(label: '720p', resolution: '720x1280 (HD)'),
        DramaQuality(label: '480p', resolution: '480x854 (Standar)'),
      ],
      unlocked: true,
      episodePrice: 0,
    );
  }
}
