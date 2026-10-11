import 'package:flutter/foundation.dart';
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

  Future<void> ensureSession() async {
    await _client.ensureSession();
  }

  @override
  String get slug => 'cinemaid';

  @override
  String get label => 'CinemaID';

  @override
  List<String> get categories => CinemaIdConfig.categories;

  /// Map kategori ke Topic ID server backend CinemaID yang valid 100%
  static const Map<String, String> _categoryToTopicId = {
    // Platform OTT (Channel 202 - Streaming module)
    'netflix': '2209',
    'disney': '2210',
    'prime video': '2211',
    'apple tv+': '2997',
    'crunchyroll': '3000',
    'max': '2999',
    'hulu': '2998',
    'paramount+': '3005',
    'amc+': '3001',
    'rakuten viki': '3004',
    // Ranking & Koleksi Utama
    'trending now': '2517',
    'trending': '2517',
    'justwatch top 100': '7950',
    'popular movies': '2193',
    'popular tv shows': '2184',
    'popular anime': '7948',
    'new korean drama series': '7953',
    'today\'s new streaming': '5214',
    'today\'s new movies': '5342',
    'today\'s new series': '5349',
  };

  /// Kembalikan URL asli langsung ke player.
  /// Proxy lokal 127.0.0.1:7000 tidak ada servernya — jangan dipakai.
  /// Sesuai perilaku APK asli: vod_url langsung ke ExoPlayer.
  String _formatStreamUrl(String rawUrl) {
    return rawUrl;
  }

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    await ensureSession();
    try {
      final catKey = category.toLowerCase().trim();

      // 1. Jalur Utama: Jika kategori memiliki topic_id server langsung
      final topicId = _categoryToTopicId[catKey];
      if (topicId != null && topicId.isNotEmpty) {
        final vods = await _client.topicVods(topicId, category: category).timeout(
              const Duration(seconds: 15),
              onTimeout: () => const <ContentItem>[],
            );
        if (vods.isNotEmpty) {
          debugPrint('CINEMAID SOURCE: loaded ${vods.length} items for topic $topicId ($category)');
          return vods;
        }
      }

      // 2. Jalur Alternatif Berdasarkan Channel
      String channelId = '202';
      if (catKey.contains('movie') || catKey.contains('film')) {
        channelId = '204';
      } else if (catKey.contains('series') || catKey.contains('tv') || catKey.contains('show')) {
        channelId = '203';
      } else if (catKey.contains('anime')) {
        channelId = '205';
      }

      final modules = await _client.channelModules(channelId: channelId).timeout(
            const Duration(seconds: 15),
            onTimeout: () => const <Map<String, dynamic>>[],
          );
      debugPrint('CINEMAID SOURCE: category=$category channelId=$channelId modules=${modules.length}');

      if (modules.isNotEmpty) {
        Map<String, dynamic>? picked;
        final needle = catKey.replaceAll(RegExp(r'[^a-z0-9]'), '');
        for (final m in modules) {
          final rawName = '${m['module_name'] ?? m['name'] ?? ''}';
          final name = rawName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (name.isNotEmpty && (name == needle || name.contains(needle) || needle.contains(name))) {
            picked = m;
            break;
          }
          final blockList = m['block_list'];
          if (blockList is List) {
            for (final b in blockList) {
              if (b is Map) {
                final bName = '${b['block_name'] ?? ''}'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                if (bName.isNotEmpty && (bName == needle || bName.contains(needle) || needle.contains(bName))) {
                  picked = m;
                  break;
                }
              }
            }
          }
          if (picked != null) break;
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
                  description: '${v['vod_blurb'] ?? v['vod_desc'] ?? v['desc'] ?? ''}',
                  posterUrl: pic,
                  backdropUrl: pic,
                  rating: double.tryParse('${v['vod_score'] ?? v['vod_douban_score'] ?? v['rating'] ?? 0}') ?? 0,
                  episodes: int.tryParse('${v['vod_total'] ?? v['vod_serial'] ?? v['vod_episode'] ?? 1}') ?? 1,
                  platformSlug: 'cinemaid',
                ));
              }
              continue;
            }

            if (b['vod_info'] is Map) {
              final v = b['vod_info'] as Map;
              final id = '${v['vod_id'] ?? v['id'] ?? ''}';
              final title = '${v['vod_name'] ?? v['title'] ?? v['name'] ?? ''}'.trim();
              final pic = '${v['vod_pic'] ?? v['pic'] ?? v['cover'] ?? ''}'.trim();
              if (id.isEmpty || title.isEmpty || !seen.add(id)) continue;
              out.add(ContentItem(
                id: id,
                title: title,
                source: 'cinemaid',
                category: category,
                description: '${v['vod_blurb'] ?? v['vod_desc'] ?? v['desc'] ?? ''}',
                posterUrl: pic,
                backdropUrl: pic,
                rating: double.tryParse('${v['vod_score'] ?? v['vod_douban_score'] ?? v['rating'] ?? 0}') ?? 0,
                episodes: int.tryParse('${v['vod_total'] ?? v['vod_serial'] ?? v['vod_episode'] ?? 1}') ?? 1,
                platformSlug: 'cinemaid',
              ));
            }
          }
        }
        debugPrint('CINEMAID SOURCE: out=${out.length} items parsed');
        if (out.isNotEmpty) return out;
      }
    } catch (e, st) {
      debugPrint('CINEMAID SOURCE ERROR: $e\n$st');
    }

    return const <ContentItem>[];
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    await ensureSession();
    // 1. Coba fetch episode live jika API info_new merespons
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

    throw Exception('CinemaID: gagal memuat episode dari server ($seriesId)');
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
  }) async {
    final cached = _streamCache['$seriesId:$episodeId'];
    if (cached != null && cached.isNotEmpty) return cached;

    // Belum di-cache: ambil ulang episode list lalu ambil kembali
    await episodes(seriesId);
    final retry = _streamCache['$seriesId:$episodeId'];
    if (retry != null && retry.isNotEmpty) return retry;

    throw Exception('CinemaID: URL stream tidak ditemukan ($seriesId/$episodeId)');
  }

  /// vod_url = stream langsung per episode (mirip FreeReels, tanpa getplayinfo).
  String _pickStreamUrl(Map<String, dynamic> e) {
    for (final k in ['vod_url', 'play_url', 'url', 'm3u8_url', 'down_url']) {
      final v = '${e[k] ?? ''}';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    await ensureSession();
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

    // Subtitle: didukung in-band HLS m3u8 playlist.
    final subtitles = <DramaSubtitle>[];

    // Kualitas video adaptive HLS stream
    final qualities = const <DramaQuality>[
      DramaQuality(label: '1080p', resolution: '1080p FHD'),
      DramaQuality(label: '720p', resolution: '720p HD'),
      DramaQuality(label: '480p', resolution: '480p SD'),
    ];

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
