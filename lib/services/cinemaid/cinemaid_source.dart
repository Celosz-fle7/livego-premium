import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'cinemaid_client.dart';
import 'cinemaid_config.dart';

/// Adapter CinemaID sebagai DramaSource.
///
/// Protokol (static teardown APK com.movieph.bj.playvibes 5.0.7):
/// - Base URL server-driven dari GET /api/public/init -> data.sys_conf.api_url
/// - Episode: GET /api/vod/info_new?vod_id=&collection= -> vod_collection[],
///   vod_url = stream langsung per episode (tanpa getplayinfo, mirip FreeReels)
/// - Subtitle: TIDAK disediakan API (kemungkinan in-band di m3u8) -> extras
///   mengembalikan daftar subtitle kosong
/// - Audio multi: audio_type_option[] dari detail
/// - Kualitas: tidak ada model di API (m3u8 adaptive)
/// - Paywall: model VIP/subscription (is_svip, vip_level, pay_status,
///   vod_duration_free), bukan coin per episode. Episode terkunci ditandai
///   di extras.unlocked=false — TIDAK ada bypass di sini.
class CinemaIdSource implements DramaSource {
  final CinemaIdClient _client = CinemaIdClient();

  /// Cache episodeId -> stream m3u8, diisi saat episodes() dipanggil.
  /// Format key: "$seriesId:$episodeId".
  final Map<String, String> _streamCache = {};

  /// Cache detail episode mentah untuk extras (audio, paywall).
  /// Format key: "$seriesId:$episodeId".
  final Map<String, Map<String, dynamic>> _episodeCache = {};

  /// Cache info detail series (untuk audio_type_option + paywall).
  Map<String, dynamic>? _lastInfo;
  String? _lastInfoSeriesId;

  CinemaIdClient get client => _client;

  @override
  String get slug => 'cinemaid';

  @override
  String get label => 'CinemaID';

  @override
  List<String> get categories => CinemaIdConfig.categories;

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    List<Map<String, dynamic>> modules = const [];
    try {
      modules = await _client.topicModules();
    } catch (_) {
      // module gagal / firewall -> fallback ke search
    }

    if (modules.isNotEmpty) {
      // Cari modul yang namanya cocok dengan kategori (case-insensitive).
      Map<String, dynamic>? picked;
      final needle = category.toLowerCase();
      for (final m in modules) {
        final name = '${m['module_name'] ?? m['name'] ?? ''}'.toLowerCase();
        if (name.isNotEmpty && (name == needle || name.contains(needle) || needle.contains(name))) {
          picked = m;
          break;
        }
      }
      final targets = picked != null ? [picked] : modules;

      final out = <ContentItem>[];
      final seen = <String>{};
      for (final m in targets) {
        final videos = m['videoList'] ?? m['video_list'] ?? m['list'] ?? const [];
        if (videos is! List) continue;
        for (final v in videos) {
          if (v is! Map) continue;
          final item = ContentItem(
            id: '${v['vod_id'] ?? v['id'] ?? ''}',
            title: '${v['vod_name'] ?? v['title'] ?? v['name'] ?? 'No title'}',
            source: 'cinemaid',
            category: category,
            description: '${v['vod_desc'] ?? v['desc'] ?? ''}',
            posterUrl: '${v['vod_pic'] ?? v['pic'] ?? v['cover'] ?? ''}',
            backdropUrl: '${v['vod_pic'] ?? v['pic'] ?? v['cover'] ?? ''}',
            rating: double.tryParse('${v['vod_score'] ?? v['rating'] ?? 0}') ?? 0,
            episodes: int.tryParse('${v['vod_episode'] ?? 0}') ?? 0,
            platformSlug: 'cinemaid',
          );
          if (item.id.isEmpty || !seen.add(item.id)) continue;
          out.add(item);
        }
      }
      if (out.isNotEmpty) return out;
    }

    // Jika modul kosong atau kategori streaming provider (Netflix, Viu, WeTV, Vidio, Prime, Hotstar):
    // Fallback panggil search API menggunakan nama kategori!
    try {
      final query = category.toLowerCase() == 'for you' ? '2024' : category;
      final searchResults = await _client.search(query);
      if (searchResults.isNotEmpty) {
        return searchResults.map((e) => ContentItem(
          id: e.id,
          title: e.title,
          source: 'cinemaid',
          category: category,
          description: e.description,
          posterUrl: e.posterUrl,
          backdropUrl: e.backdropUrl,
          rating: e.rating,
          episodes: e.episodes,
          platformSlug: 'cinemaid',
        )).toList();
      }
    } catch (_) {}

    return const [];
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    final data = await _client.vodInfo(seriesId);
    final info = data['info'] as Map<String, dynamic>;
    _lastInfo = info;
    _lastInfoSeriesId = seriesId;

    final raw = data['episodes'] as List<Map<String, dynamic>>;
    final out = <LiveGoEpisode>[];
    var idx = 1;
    for (final e in raw) {
      final epNum = int.tryParse('${e['episodeNum'] ?? e['episode_num'] ?? e['num'] ?? idx}') ?? idx;
      final id = '${e['vod_id'] ?? e['id'] ?? ''}'.isNotEmpty
          ? '${e['vod_id'] ?? e['id']}'
          : '$seriesId:$epNum';
      final url = _pickStreamUrl(e);
      if (url.isNotEmpty) _streamCache['$seriesId:$id'] = url;
      _episodeCache['$seriesId:$id'] = e;
      out.add(LiveGoEpisode(
        id: id,
        index: epNum,
        title: '${e['title'] ?? e['vod_name'] ?? 'Episode $epNum'}',
      ));
      idx++;
    }
    return out;
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
  }) async {
    final cached = _streamCache['$seriesId:$episodeId'];
    if (cached != null && cached.isNotEmpty) return cached;

    // Belum di-cache: ambil ulang detail lalu cari episode-nya.
    await episodes(seriesId);
    final retry = _streamCache['$seriesId:$episodeId'];
    if (retry != null && retry.isNotEmpty) return retry;
    throw Exception('CinemaID: stream URL tidak ditemukan ($seriesId/$episodeId)');
  }

  /// vod_url = stream langsung per episode (mirip FreeReels, tanpa getplayinfo).
  String _pickStreamUrl(Map<String, dynamic> e) {
    for (final k in ['vod_url', 'play_url', 'url', 'm3u8_url']) {
      final v = '${e[k] ?? ''}';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  @override
  Future<List<ContentItem>> search(String query) {
    return _client.search(query);
  }

  /// Cek apakah episode terkunci paywall.
  ///
  /// Model VIP/subscription: is_svip / vip_level / pay_status / vod_duration_free.
  /// Tidak ada field coin per episode seperti FreeReels; kalau server menandai
  /// butuh VIP -> unlocked=false. Tidak ada logika bypass.
  bool _isLocked(Map<String, dynamic> episode, Map<String, dynamic>? info) {
    final ep = episode;
    final flags = <Object?>[
      ep['is_svip'],
      ep['pay_status'],
      ep['need_vip'],
      ep['is_vip'],
      info?['is_svip'],
      info?['pay_status'],
    ];
    for (final f in flags) {
      final s = '$f'.toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') return true;
    }
    final level = int.tryParse('${ep['vip_level'] ?? info?['vip_level'] ?? 0}') ?? 0;
    if (level > 0) return true;
    return false;
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async {
    var raw = _episodeCache['$seriesId:$episodeId'];
    if (raw == null) {
      await episodes(seriesId);
      raw = _episodeCache['$seriesId:$episodeId'];
    }
    if (raw == null) return null;

    // Subtitle: tidak disediakan API CinemaID (inferensi: in-band di m3u8).
    final subtitles = <DramaSubtitle>[];

    // Kualitas: tidak ada model di API (m3u8 adaptive).
    final qualities = <DramaQuality>[];

    // Audio multi dari audio_type_option[] (episode atau detail series).
    final audioLangs = <String>[];
    final seen = <String>{};
    void collect(Object? rawList) {
      if (rawList is List) {
        for (final a in rawList) {
          final s = a is Map ? '${a['name'] ?? a['label'] ?? a['type'] ?? ''}' : '$a';
          if (s.isNotEmpty && seen.add(s)) audioLangs.add(s);
        }
      }
    }
    collect(raw['audio_type_option']);
    if (_lastInfoSeriesId == seriesId && _lastInfo != null) {
      collect(_lastInfo!['audio_type_option']);
    }

    final locked = _isLocked(raw, _lastInfoSeriesId == seriesId ? _lastInfo : null);

    return DramaEpisodeExtras(
      subtitles: subtitles,
      qualities: qualities,
      audioLanguages: audioLangs,
      unlocked: !locked,
      episodePrice: 0,
    );
  }
}
