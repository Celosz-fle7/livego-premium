import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'shortdrama_client.dart';
import 'shortdrama_config.dart';

/// Adapter ShortDrama TV sebagai DramaSource di LiveGo.
///
/// Alur (hasil reverse engineering APK com.shortdramatv.rlles):
///   1. /api/channel/get_list   -> tab bawaan
///   2. /api/channel/get_info   -> feed per tab (paginasi pn/psize)
///   3. /api/vod_short/list_new -> short drama + show_collection_play_url
///   4. series_hash diambil dari play_url -> path episode
///   5. URL video di-sign sendiri: md5(key + path + wsTimeHex)
class ShortDramaSource implements DramaSource {
  final ShortDramaClient _client = ShortDramaClient.instance;

  /// channel_name (label Indonesia) -> channel_id.
  final Map<String, int> _channelIds = {};

  /// seriesId -> series_hash (dari show_collection_play_url).
  final Map<String, String> _seriesHash = {};

  /// seriesId -> bahasa audio di CDN ('id' / 'es'), dari play_url.
  final Map<String, String> _seriesLang = {};

  /// seriesId -> total episode.
  final Map<String, int> _seriesTotal = {};

  /// "$seriesId:$episodeId" -> signed stream URL.
  final Map<String, String> _streamCache = {};

  bool _channelsLoaded = false;

  @override
  String get slug => 'shortdrama';

  @override
  String get label => 'ShortDrama';

  @override
  List<String> get categories => ShortDramaConfig.categories;

  /// Muat daftar channel dari server sekali, isi _channelIds.
  Future<void> _ensureChannels() async {
    if (_channelsLoaded) return;
    try {
      final list = await _client.channelList();
      for (final c in list) {
        final id = c['id'];
        final name = '${c['channel_name'] ?? ''}'.toLowerCase().trim();
        if (id is int) {
          final label = ShortDramaConfig.channelNameMap[name] ?? name;
          _channelIds[label] = id;
        }
      }
      _channelsLoaded = true;
    } catch (_) {
      // biarkan; kategori fallback ke list_new
    }
  }

  /// Daftarkan series (hash + bahasa + total) dari item API mentah.
  void _registerFromRaw(List<Map<String, dynamic>> raw) {
    for (final m in raw) {
      final id = '${m['id'] ?? m['vod_id'] ?? ''}';
      if (id.isEmpty) continue;
      final playUrl = '${m['show_collection_play_url'] ?? ''}';
      final hash = extractSeriesHash(playUrl);
      final lang = extractSeriesLang(playUrl);
      final total = int.tryParse('${m['vod_total'] ?? m['vod_serial'] ?? 0}') ?? 0;
      if (hash.isNotEmpty) _seriesHash[id] = hash;
      if (lang.isNotEmpty) _seriesLang[id] = lang;
      if (total > 0) _seriesTotal[id] = total;
    }
  }

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    final res = await homePage(category, page: 1, pageSize: 30);
    return res.items;
  }

  @override
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) async {
    await _ensureChannels();

    final channelId = _channelIds[category];
    if (channelId != null) {
      try {
        final res = await _client.channelInfo(
          channelId: channelId,
          page: page,
          pageSize: pageSize,
          category: category,
        );
        if (res.items.isNotEmpty) {
          _registerFromRaw(res.raw);
          return (items: res.items, hasMore: res.hasMore);
        }
      } catch (_) {}
    }

    // Fallback: halaman 1 pakai list_new (tanpa paginasi server).
    if (page <= 1) {
      try {
        final raw = await _client.vodShortNewRaw();
        if (raw.isNotEmpty) {
          _registerFromRaw(raw);
          return (items: _client.mapAll(raw, category), hasMore: false);
        }
      } catch (_) {}
    }
    return (items: <ContentItem>[], hasMore: false);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    // ShortDrama tidak punya endpoint episode terpisah untuk short drama:
    // jumlah episode = vod_total, path berpola {ep}.mp4.
    final total = _seriesTotal[seriesId] ?? 0;
    final count = total > 0 ? total : 1;
    return List<LiveGoEpisode>.generate(
      count,
      (i) => LiveGoEpisode(
        id: '${i + 1}',
        index: i + 1,
        title: 'Episode ${i + 1}',
      ),
    );
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final key = '$seriesId:$episodeId';
    final cached = _streamCache[key];
    if (cached != null && cached.isNotEmpty) return cached;

    final hash = _seriesHash[seriesId];
    if (hash == null || hash.isEmpty) {
      throw Exception('ShortDrama: series_hash tidak dikenal ($seriesId)');
    }

    final lang = _seriesLang[seriesId] ?? ShortDramaConfig.videoLang;
    final ep = int.tryParse(episodeId) ?? 1;
    final path = '/series/$hash/translated/$lang/$ep.mp4';
    final url = signVideoUrl(path);
    _streamCache[key] = url;
    return url;
  }

  /// Sign URL video CDN (nginx secure_link style).
  /// wsSecret = md5(key + path + wsTimeHex); wsTime = hex(unix seconds).
  static String signVideoUrl(String path, {DateTime? at}) {
    final ts = (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    final wsTime = ts.toRadixString(16);
    final wsSecret = md5
        .convert(utf8.encode('${ShortDramaConfig.videoSignKey}$path$wsTime'))
        .toString();
    return '${ShortDramaConfig.cdnBase}$path?wsSecret=$wsSecret&wsTime=$wsTime';
  }

  /// Ambil series_hash dari URL play (segmen setelah /series/).
  static String extractSeriesHash(String playUrl) {
    final marker = '/series/';
    final idx = playUrl.indexOf(marker);
    if (idx < 0) return '';
    final rest = playUrl.substring(idx + marker.length);
    final slash = rest.indexOf('/');
    return slash < 0 ? rest : rest.substring(0, slash);
  }

  /// Ambil bahasa audio dari URL play: /series/{hash}/translated/{lang}/{ep}.mp4
  static String extractSeriesLang(String playUrl) {
    final marker = '/translated/';
    final idx = playUrl.indexOf(marker);
    if (idx < 0) return '';
    final rest = playUrl.substring(idx + marker.length);
    final slash = rest.indexOf('/');
    final lang = slash < 0 ? rest : rest.substring(0, slash);
    return lang.trim();
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    final raw = await _client.searchRaw(query);
    _registerFromRaw(raw);
    return _client.mapAll(raw, 'Pencarian');
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(String seriesId, String episodeId) async {
    return const DramaEpisodeExtras(
      subtitles: [],
      qualities: [DramaQuality(label: 'AUTO', resolution: 'auto')],
      audioLanguages: ['id'],
      unlocked: true,
    );
  }

  @override
  Future<void> signOut() async {
    _streamCache.clear();
  }
}
