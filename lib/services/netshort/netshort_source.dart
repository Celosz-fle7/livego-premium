import 'package:flutter/foundation.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'netshort_client.dart';

/// Provider NetShort untuk LiveGO.
/// Menghubungkan discovery channel video, chart ranking, detail drama,
/// daftar episode, dan pemutaran direct video MP4 CloudFront/AWS CDN + WebVTT subtitle.
class NetShortSource implements DramaSource {
  final NetShortClient _client = NetShortClient.instance;

  NetShortClient get client => _client;

  @override
  String get slug => 'netshort';

  @override
  String get label => 'NetShort';

  /// Kategori tab bawaan (Bahasa Indonesia & Populer)
  @override
  List<String> get categories => const [
        'Populer',
        'Trending',
        'Rilis Baru',
        'Kepuasan',
        'Sang Juara Kembali',
        'Bangkit Kembali',
        'Menghukum Penjahat',
        'Pertumbuhan Wanita',
        'Romantis Perkotaan',
      ];

  /// Mapping nama kategori ke channelId jika cocok
  static const Map<String, int> _categoryChannelIds = {
    'Populer': 345,
    'Kepuasan': 346,
    'Sang Juara Kembali': 347,
    'Bangkit Kembali': 348,
    'Menghukum Penjahat': 349,
    'Pertumbuhan Wanita': 350,
    'Romantis Perkotaan': 351,
  };

  /// Cache episode extras (playVoucher, subtitles, qualities)
  final Map<String, DramaEpisodeExtras> _extrasCache = {};

  /// Cache direct stream URL
  final Map<String, String> _streamCache = {};

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    final cat = category.trim();

    try {
      // Jika tab ranking khusus
      if (cat.toLowerCase() == 'trending' || cat.toLowerCase() == 'rilis baru') {
        final rankingList = await _client.getRankingCharts();
        if (rankingList.isNotEmpty) {
          return rankingList.map(_mapToContentItem).toList();
        }
      }

      final channelId = _categoryChannelIds[cat] ?? 345;
      final videos = await _client.getChannelVideos(channelId);
      if (videos.isNotEmpty) {
        return videos.map(_mapToContentItem).toList();
      }

      // Fallback ambil ranking charts jika channel video kosong
      final fallbacks = await _client.getRankingCharts();
      if (fallbacks.isNotEmpty) {
        return fallbacks.map(_mapToContentItem).toList();
      }
    } catch (e, stack) {
      debugPrint('NETSHORT HOME BY CATEGORY ERROR: $e\n$stack');
      try {
        final fallbacks = await _client.getRankingCharts();
        return fallbacks.map(_mapToContentItem).toList();
      } catch (_) {}
    }
    return const [];
  }

  @override
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) async {
    // NetShort theater channel mengembalikan seluruh list per kanal sekaligus
    final items = await homeByCategory(category);
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= items.length) {
      return (items: <ContentItem>[], hasMore: false);
    }
    final endIndex = (startIndex + pageSize).clamp(0, items.length);
    final paged = items.sublist(startIndex, endIndex);
    final hasMore = endIndex < items.length;
    return (items: paged, hasMore: hasMore);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    final detail = await _client.getDetailInfoV2(seriesId);
    final rawEpisodes = detail['shortPlayEpisodeInfos'] as List<dynamic>? ?? [];

    final List<LiveGoEpisode> list = [];
    for (final raw in rawEpisodes) {
      if (raw is! Map<String, dynamic>) continue;
      final epId = raw['episodeId']?.toString() ?? '';
      final epNo = int.tryParse(raw['episodeNo']?.toString() ?? '') ?? (list.length + 1);
      final playVoucher = raw['playVoucher']?.toString() ?? '';

      // Cache episode stream URL jika sudah tersedia langsung
      if (playVoucher.isNotEmpty) {
        _streamCache['$seriesId:$epId:auto'] = playVoucher;
        _streamCache['$seriesId:$epId'] = playVoucher;
      }

      // Parse subtitle list
      final rawSubs = raw['subtitleList'] as List<dynamic>? ?? [];
      final List<DramaSubtitle> subtitles = [];
      for (final s in rawSubs) {
        if (s is Map<String, dynamic>) {
          final lang = s['subtitleLanguage']?.toString() ?? s['language']?.toString() ?? 'id_ID';
          final subUrl = s['url']?.toString() ?? s['subtitleUrl']?.toString() ?? '';
          if (subUrl.isNotEmpty) {
            subtitles.add(DramaSubtitle(
              language: lang,
              displayName: lang == 'id_ID' ? 'Indonesia' : lang,
              url: subUrl,
            ));
          }
        }
      }

      // Parse resolution / clarity
      final clarity = raw['playClarity']?.toString() ?? '540p';
      final List<DramaQuality> qualities = [
        DramaQuality(label: clarity.toUpperCase(), resolution: clarity),
      ];

      _extrasCache['$seriesId:$epId'] = DramaEpisodeExtras(
        subtitles: subtitles,
        qualities: qualities,
        audioLanguages: const ['id'],
        unlocked: true,
      );

      list.add(LiveGoEpisode(
        id: epId,
        index: epNo,
        title: 'Episode $epNo',
      ));
    }

    return list;
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final cacheKey = '$seriesId:$episodeId:${quality ?? 'auto'}';
    final cached = _streamCache[cacheKey] ?? _streamCache['$seriesId:$episodeId'];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // Ambil detail info episode khusus jika belum ada voucher
    final epDetails = await _client.getEpisodeDetailInfo(
      shortPlayId: seriesId,
      episodeIds: [episodeId],
    );

    if (epDetails.isNotEmpty) {
      final ep = epDetails.first;
      final voucher = ep['playVoucher']?.toString() ?? '';
      if (voucher.isNotEmpty) {
        _streamCache[cacheKey] = voucher;
        _streamCache['$seriesId:$episodeId'] = voucher;

        final rawSubs = ep['subtitleList'] as List<dynamic>? ?? [];
        final List<DramaSubtitle> subtitles = [];
        for (final s in rawSubs) {
          if (s is Map<String, dynamic>) {
            final lang = s['subtitleLanguage']?.toString() ?? s['language']?.toString() ?? 'id_ID';
            final subUrl = s['url']?.toString() ?? s['subtitleUrl']?.toString() ?? '';
            if (subUrl.isNotEmpty) {
              subtitles.add(DramaSubtitle(
                language: lang,
                displayName: lang == 'id_ID' ? 'Indonesia' : lang,
                url: subUrl,
              ));
            }
          }
        }

        final clarity = ep['playClarity']?.toString() ?? '540p';
        final List<DramaQuality> qualities = [
          DramaQuality(label: clarity.toUpperCase(), resolution: clarity),
        ];

        _extrasCache['$seriesId:$episodeId'] = DramaEpisodeExtras(
          subtitles: subtitles,
          qualities: qualities,
          audioLanguages: const ['id'],
          unlocked: true,
        );

        return voucher;
      }
    }

    return '';
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(String seriesId, String episodeId) async {
    final key = '$seriesId:$episodeId';
    if (_extrasCache.containsKey(key)) {
      return _extrasCache[key];
    }

    // Trigger fetch streamUrl untuk populate extras
    await streamUrl(seriesId: seriesId, episodeId: episodeId);
    return _extrasCache[key];
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];

    final rawResults = await _client.searchRealtime(clean);
    return rawResults.map(_mapToContentItem).toList();
  }

  @override
  Future<void> signOut() async {
    _client.signOut();
    _extrasCache.clear();
    _streamCache.clear();
  }

  ContentItem _mapToContentItem(Map<String, dynamic> item) {
    final id = item['shortPlayId']?.toString() ?? item['id']?.toString() ?? '';
    final title = item['shortPlayName']?.toString() ?? item['title']?.toString() ?? 'Drama NetShort';
    final cover = item['shortPlayCover']?.toString() ??
        item['coverUrl']?.toString() ??
        item['posterUrl']?.toString() ??
        item['groupShortPlayCover']?.toString() ??
        '';
    final desc = item['shotIntroduce']?.toString() ?? item['introduce']?.toString() ?? '';
    final totalEp = int.tryParse(item['totalEpisode']?.toString() ?? '') ?? 1;

    return ContentItem(
      id: id,
      title: title,
      source: 'NetShort',
      category: 'Drama',
      description: desc,
      posterUrl: cover,
      backdropUrl: cover,
      rating: 9.5,
      episodes: totalEp,
      platformSlug: slug,
      lang: 'id',
    );
  }
}
