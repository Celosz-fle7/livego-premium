import 'dart:convert';
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

  static const _sampleLiveStreams = [
    'http://movieph.xrrqe.com/vod/2/2024/10/16/4a45db05b9d9/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2024/11/07/8b3c96d7e900/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/09/03/0eb2b5357f28/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/05/06/ce959dcea6bf/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/05/01/3a00a29c96a5/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/05/13/a2aaace5f9dc/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/08/13/3ab752e95849/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2024/10/21/3f000f472bd3/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2025/12/10/b6378e100290/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/09/16/4f89dce66ec1/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2025/12/22/3193cf57c602/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/10/03/61dc6137ebf2/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/08/05/c8e579d215a7/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/10/10/b2201a456c6a/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/05/28/eb3234b44b27/index5.m3u8',
    'http://movieph.xrrqe.com/vod/2/2026/06/02/765614164dee/index5.m3u8',
  ];

  /// Format URL ke proxy lokal CinemaID (127.0.0.1:7000) jika raw stream dari CDN movieph.
  String _formatStreamUrl(String rawUrl) {
    if (rawUrl.isEmpty) return rawUrl;
    if (rawUrl.startsWith('http://127.0.0.1:') || rawUrl.startsWith('http://localhost:')) {
      return rawUrl;
    }
    try {
      final b64 = base64.encode(utf8.encode(rawUrl));
      return 'http://127.0.0.1:7000/resource.m3u8?src=$b64';
    } catch (_) {
      return rawUrl;
    }
  }

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    // 1. Coba ambil dari network live dengan timeout 4 detik
    try {
      final modules = await _client.topicModules().timeout(
            const Duration(seconds: 4),
            onTimeout: () => const <Map<String, dynamic>>[],
          );
      if (modules.isNotEmpty) {
        Map<String, dynamic>? picked;
        final needle = category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        for (final m in modules) {
          final rawName = '${m['module_name'] ?? m['name'] ?? ''}';
          final name = rawName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (name.isNotEmpty && (name == needle || name.contains(needle) || needle.contains(name))) {
            picked = m;
            break;
          }
        }
        final targets = picked != null ? [picked] : modules;
        final out = <ContentItem>[];
        final seen = <String>{};
        for (final m in targets) {
          final blockList = m['block_list'] ?? m['videoList'] ?? m['video_list'] ?? m['list'] ?? const [];
          if (blockList is! List) continue;
          for (final b in blockList) {
            if (b is! Map) continue;
            final subVods = b['vod_list'];
            if (subVods is List && subVods.isNotEmpty) {
              for (final v in subVods) {
                if (v is! Map) continue;
                final id = '${v['vod_id'] ?? v['id'] ?? ''}';
                final title = '${v['vod_name'] ?? v['title'] ?? v['name'] ?? ''}'.trim();
                final pic = '${v['vod_pic'] ?? v['pic'] ?? v['cover'] ?? ''}'.trim();
                if (id.isEmpty || title.isEmpty || !seen.add(id)) continue;
                out.add(ContentItem(
                  id: id,
                  title: title,
                  source: 'cinemaid',
                  category: category,
                  description: '${v['vod_desc'] ?? v['desc'] ?? v['vod_blurb'] ?? ''}',
                  posterUrl: pic,
                  backdropUrl: pic,
                  rating: double.tryParse('${v['vod_score'] ?? v['vod_douban_score'] ?? v['rating'] ?? 0}') ?? 0,
                  episodes: int.tryParse('${v['vod_episode'] ?? v['vod_total'] ?? 0}') ?? 0,
                  platformSlug: 'cinemaid',
                ));
              }
              continue;
            }

            final v = (b['vod_info'] is Map ? b['vod_info'] : b) as Map;
            final id = '${v['vod_id'] ?? v['id'] ?? v['data_id'] ?? ''}';
            final title = '${v['vod_name'] ?? v['title'] ?? v['name'] ?? ''}'.trim();
            final pic = '${v['vod_pic'] ?? v['pic'] ?? v['cover'] ?? b['banner_pic'] ?? ''}'.trim();
            if (id.isEmpty || title.isEmpty || !seen.add(id)) continue;
            out.add(ContentItem(
              id: id,
              title: title,
              source: 'cinemaid',
              category: category,
              description: '${v['vod_desc'] ?? v['desc'] ?? v['vod_blurb'] ?? ''}',
              posterUrl: pic,
              backdropUrl: pic,
              rating: double.tryParse('${v['vod_score'] ?? v['vod_douban_score'] ?? v['rating'] ?? 0}') ?? 0,
              episodes: int.tryParse('${v['vod_episode'] ?? v['vod_total'] ?? 0}') ?? 0,
              platformSlug: 'cinemaid',
            ));
          }
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}

    return const <ContentItem>[];
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    // 1. Coba fetch episode live jika ID bukan seed dummy
    if (!seriesId.startsWith('cinemaid_')) {
      try {
        final data = await _client.vodInfo(seriesId);
        final info = data['info'] as Map<String, dynamic>;
        _lastInfo = info;
        _lastInfoSeriesId = seriesId;

        final raw = data['episodes'] as List<Map<String, dynamic>>;
        if (raw.isNotEmpty) {
          final out = <LiveGoEpisode>[];
          var idx = 1;
          for (final e in raw) {
            final epNum = int.tryParse('${e['episodeNum'] ?? e['episode_num'] ?? e['num'] ?? idx}') ?? idx;
            final id = '${e['vod_id'] ?? e['id'] ?? ''}'.isNotEmpty
                ? '${e['vod_id'] ?? e['id']}'
                : '$seriesId:$epNum';
            final url = _pickStreamUrl(e);
            if (url.isNotEmpty) _streamCache['$seriesId:$id'] = _formatStreamUrl(url);
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
      } catch (_) {}
    }

    final epId = '$seriesId:1';
    final rawStream = _sampleLiveStreams[(int.tryParse(seriesId) ?? 1) % _sampleLiveStreams.length];
    _streamCache['$seriesId:$epId'] = _formatStreamUrl(rawStream);
    return [
      LiveGoEpisode(
        id: epId,
        index: 1,
        title: 'Full Movie',
      ),
    ];
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
  }) async {
    final cached = _streamCache['$seriesId:$episodeId'];
    if (cached != null && cached.isNotEmpty) return _formatStreamUrl(cached);

    // Belum di-cache: ambil ulang detail lalu cari episode-nya.
    await episodes(seriesId);
    final retry = _streamCache['$seriesId:$episodeId'];
    if (retry != null && retry.isNotEmpty) return _formatStreamUrl(retry);
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
