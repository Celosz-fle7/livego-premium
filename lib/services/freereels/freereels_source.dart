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

  /// Cache episodeId -> stream m3u8, diisi saat episodes() dipanggil.
  /// Format key: "$seriesId:$episodeId".
  final Map<String, String> _streamCache = {};

  /// Cache data episode mentah untuk extras (subtitle, kualitas, unlock).
  /// Format key: "$seriesId:$episodeId".
  final Map<String, Map<String, dynamic>> _episodeCache = {};

  /// ID yang sudah dikembalikan homePage per kategori (reset tiap page 1).
  /// Dipakai mendeteksi halaman habis: server balikin duplikat semua =
  /// tidak ada konten baru lagi (pola yang sama dipakai allSeriesFromTab).
  final Map<String, Set<String>> _pageSeen = {};

  /// Token search per kategori untuk paginasi Sulih Suara.
  /// tokens[i] = pageToken untuk halaman i+1; tokens[0] = '' (halaman 1).
  /// Pagination jalan sekuensial (1 -> 2 -> 3); kalau loncat, token
  /// diisi dengan jalan dari token terakhir yang dikenal.
  final Map<String, List<String>> _searchTokens = {};

  /// Kategori yang search-nya sudah habis (nextToken kosong).
  final Set<String> _searchExhausted = {};

  @override
  String get slug => 'freereels';

  @override
  String get label => 'FreeReels';

  @override
  List<String> get categories => FreereelsConfig.tabKeys.keys.toList(growable: false);

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    final tabKey =
        FreereelsConfig.tabKeys[category] ?? FreereelsConfig.tabKeys['Popular']!;
    // Ambil semua halaman (paginasi) agar konten maksimal per tab.
    final items = await _client.allSeriesFromTab(tabKey: tabKey, category: category);

    // Workaround: tab Sulih Suara di API cuma sedikit item.
    // Tambah hasil search "sulih suara" dengan paginasi penuh (ratusan judul).
    if (category == 'Sulih Suara') {
      try {
        final searchItems = await _client.searchAll('sulih suara', maxPages: 20);
        final seen = items.map((e) => e.id).toSet();
        for (final s in searchItems) {
          if (seen.add(s.id)) items.add(s);
        }
      } catch (_) {}
    }
    return items;
  }

  @override
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) async {
    // SATU tabFeed per halaman (bukan allSeriesFromTab + searchAll yang
    // bikin load berat). position_index melangkah 10 — pola yang sudah
    // terbukti di allSeriesFromTab; jumlah per halaman ikut server.
    final tabKey =
        FreereelsConfig.tabKeys[category] ?? FreereelsConfig.tabKeys['Popular']!;
    if (page <= 1) {
      _pageSeen[category] = <String>{};
      _searchTokens.remove(category);
      _searchExhausted.remove(category);
    }
    final seen = _pageSeen.putIfAbsent(category, () => <String>{});
    final batch = await _client.tabFeed(
      tabKey: tabKey,
      positionIndex: (page - 1) * 10,
      category: category,
    );
    final fresh = <ContentItem>[];
    for (final item in batch) {
      if (seen.add(item.id)) fresh.add(item);
    }
    var hasMore = batch.isNotEmpty && fresh.isNotEmpty;

    // Sulih Suara = konten trending/Indonesia: tab 514 saja cuma sedikit
    // item. Gabung satu halaman search "sulih suara" (ratusan judul) agar
    // SEMUA konten sulih suara ketarik — di jalur paged juga, bukan cuma
    // homeByCategory (legacy).
    if (category == 'Sulih Suara' && !_searchExhausted.contains(category)) {
      try {
        final tokens =
            _searchTokens.putIfAbsent(category, () => <String>['']);
        // Pastikan token halaman ini ada (pagination sekuensial).
        while (tokens.length < page) {
          final probe = await _client.searchPage(
            'sulih suara',
            pageToken: tokens.last,
            category: category,
          );
          tokens.add(probe.nextToken);
          if (probe.nextToken.isEmpty) {
            _searchExhausted.add(category);
            break;
          }
        }
        if (page <= tokens.length) {
          final res = await _client.searchPage(
            'sulih suara',
            pageToken: tokens[page - 1],
            category: category,
          );
          for (final item in res.items) {
            if (seen.add(item.id)) fresh.add(item);
          }
          if (tokens.length == page) tokens.add(res.nextToken);
          if (res.nextToken.isEmpty) {
            _searchExhausted.add(category);
          } else {
            hasMore = true;
          }
        }
      } catch (_) {}
    }
    return (items: fresh, hasMore: hasMore);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    final raw = await _client.episodeList(seriesId);
    final out = <LiveGoEpisode>[];
    for (final e in raw) {
      final id = '${e['id'] ?? ''}';
      if (id.isEmpty) continue;
      final url = _pickStreamUrl(e);
      if (url.isNotEmpty) _streamCache['$seriesId:$id'] = url;
      _episodeCache['$seriesId:$id'] = e;
      out.add(LiveGoEpisode(
        id: id,
        index: int.tryParse('${e['index'] ?? 0}') ?? 0,
        title: '${e['name'] ?? 'Episode ${e['index'] ?? ''}'}',
      ));
    }
    return out;
  }

  @override
  Future<String> streamUrl({required String seriesId, required String episodeId, String? quality}) async {
    final cached = _streamCache['$seriesId:$episodeId'];
    if (cached != null && cached.isNotEmpty) return cached;

    // Belum di-cache: ambil ulang episode list lalu cari episode-nya.
    final raw = await _client.episodeList(seriesId);
    for (final e in raw) {
      if ('${e['id'] ?? ''}' == episodeId) {
        final url = _pickStreamUrl(e);
        if (url.isNotEmpty) {
          _streamCache['$seriesId:$episodeId'] = url;
          return url;
        }
      }
    }
    throw Exception('FreeReels: stream URL tidak ditemukan ($seriesId/$episodeId)');
  }

  /// Pilih URL stream terbaik dari item episode.
  /// Verified: external_audio_h264_m3u8 -> 200 audio/x-mpegurl (master playlist).
  String _pickStreamUrl(Map<String, dynamic> e) {
    for (final k in ['external_audio_h264_m3u8', 'm3u8_url', 'external_audio_h265_m3u8']) {
      final v = '${e[k] ?? ''}';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  @override
  Future<List<ContentItem>> search(String query) {
    return _client.search(query);
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async {
    var raw = _episodeCache['$seriesId:$episodeId'];
    if (raw == null) {
      // Belum di-cache: ambil episode list dulu.
      await episodes(seriesId);
      raw = _episodeCache['$seriesId:$episodeId'];
    }
    if (raw == null) return null;

    final subtitles = <DramaSubtitle>[];
    final subList = raw['subtitle_list'] as List? ?? const [];
    for (final s in subList) {
      final m = s as Map;
      final url = '${m['vtt'] ?? m['subtitle'] ?? ''}';
      if (url.isEmpty) continue;
      subtitles.add(DramaSubtitle(
        language: '${m['language'] ?? ''}',
        displayName: '${m['display_name'] ?? m['language'] ?? ''}',
        url: url,
      ));
    }

    final qualities = <DramaQuality>[];
    final res = '${raw['trans_resolution'] ?? ''}';
    for (final r in res.split(',')) {
      final t = r.trim();
      if (t.isEmpty) continue;
      final h = t.split('x');
      final label = h.length == 2 ? '${h[1]}p' : t;
      qualities.add(DramaQuality(label: label, resolution: t));
    }

    final audioLangs = <String>[];
    final audio = raw['audio'] as List?;
    if (audio != null) {
      for (final a in audio) {
        audioLangs.add('$a');
      }
    }

    return DramaEpisodeExtras(
      subtitles: subtitles,
      qualities: qualities,
      audioLanguages: audioLangs,
      unlocked: raw['unlock'] != false,
      episodePrice: int.tryParse('${raw['episode_price'] ?? 0}') ?? 0,
    );
  }

  /// FreeReels anonim — tidak ada sesi, tidak ada yang perlu keluar.
  @override
  Future<void> signOut() async {}
}
