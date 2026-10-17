import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'moviebox_client.dart';
import 'moviebox_filters.dart';

/// Provider Livego-drama untuk LiveGO (Movie & TV Series).
/// Menggantikan CinemaID dengan katalog film layar lebar bioskop, serial TV / drakor,
/// anime, dan video musik dengan direct stream MP4 multi-resolusi serta subtitle SRT.
class LivegoDramaSource implements DramaSource {
  final MovieBoxClient _client = MovieBoxClient.instance;

  /// Cache kategori -> List ContentItem
  final Map<String, List<ContentItem>> _categoryCache = {};

  /// Cache episode extras (subtitle SRT & pilihan resolusi)
  final Map<String, DramaEpisodeExtras> _extrasCache = {};

  /// Cache direct stream URL per seriesId
  final Map<String, String> _streamCache = {};

  /// Cache metadata resource per seriesId
  final Map<String, Map<String, dynamic>> _resourceCache = {};

  MovieBoxClient get client => _client;

  @override
  String get slug => 'livegodrama';

  @override
  String get label => 'Livego-drama';

  @override
  List<String> get categories => const [
        'Disarankan',
        'Trending',
        'Film',
        'TV/Serial',
        'Anime',
        'Musik',
        'Anak-anak',
      ];

  static const Map<String, int> _tabMapping = {
    'disarankan': 0,
    'trending': 1,
    'film': 2,
    'tv/serial': 5,
    'serial': 5,
    'anime': 8,
    'musik': 4,
    'anak-anak': 23,
  };

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    final normCat = category.trim().toLowerCase();
    if (_categoryCache.containsKey(normCat) && _categoryCache[normCat]!.isNotEmpty) {
      return _categoryCache[normCat]!;
    }

    final tabId = _tabMapping[normCat] ?? 0;

    try {
      final data = await _client.fetchTabOperating(tabId);
      final rawItems = data['items'] as List<dynamic>? ?? [];

      final allSubjects = <ContentItem>[];
      for (final block in rawItems) {
        if (block is! Map<String, dynamic>) continue;
        final subjects = block['subjects'] as List<dynamic>? ?? [];
        for (final s in subjects) {
          if (s is Map<String, dynamic>) {
            final item = _mapSubjectToContentItem(s, category);
            if (item.id.isNotEmpty) {
              allSubjects.add(item);
            }
          }
        }
      }

      // Jika kategori tertentu kosong dari tab operating, coba ambil dari search rank
      if (allSubjects.isEmpty && (normCat == 'film' || normCat == 'trending')) {
        final hotList = await _client.fetchSearchRank();
        for (final cat in hotList) {
          final items = cat['items'] as List<dynamic>? ?? [];
          for (final it in items) {
            if (it is Map<String, dynamic>) {
              allSubjects.add(_mapSubjectToContentItem(it, category));
            }
          }
        }
      }

      final deduped = _dedupe(MovieBoxFilters.stripAdult(allSubjects));
      if (deduped.isNotEmpty) {
        _categoryCache[normCat] = deduped;
        return deduped;
      }
    } catch (e, stack) {
      debugPrint('[LivegoDramaSource] homeByCategory error: $e\n$stack');
    }

    return const [];
  }

  @override
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) async {
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
  Future<void> signOut() async {
    _categoryCache.clear();
    _extrasCache.clear();
    _streamCache.clear();
    _resourceCache.clear();
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    try {
      final resData = await _client.fetchSubjectResource(seriesId);
      _resourceCache[seriesId] = resData;

      final rawList = resData['list'] as List<dynamic>? ?? [];
      final subjectType = (resData['subjectType'] as num?)?.toInt() ?? 1;

      // Jika Movie (subjectType == 1), kembalikan 1 episode "Full Movie"
      if (subjectType == 1 || rawList.isEmpty || (rawList.length == 1 && rawList.first['episode'] == 0)) {
        return [
          LiveGoEpisode(
            id: 'full_movie',
            index: 1,
            title: 'Full Movie',
          )
        ];
      }

      // Jika Series / TV Show (subjectType == 2)
      final episodes = <LiveGoEpisode>[];
      for (var i = 0; i < rawList.length; i++) {
        final item = rawList[i];
        if (item is! Map<String, dynamic>) continue;
        final epNum = (item['episode'] as num?)?.toInt() ?? (i + 1);
        final resId = '${item['resourceId'] ?? item['id'] ?? epNum}';
        final epTitle = (item['title'] as String?)?.trim();
        final displayTitle = (epTitle != null && epTitle.isNotEmpty)
            ? epTitle
            : 'Episode $epNum';

        episodes.add(LiveGoEpisode(id: resId, index: epNum, title: displayTitle));

        final resLink = (item['resourceLink'] as String?)?.trim() ?? '';
        if (resLink.isNotEmpty) {
          _streamCache['$seriesId:$resId'] = resLink;
        }
      }

      if (episodes.isNotEmpty) {
        return episodes;
      }
    } catch (e) {
      debugPrint('[LivegoDramaSource] episodes error: $e');
    }

    return [LiveGoEpisode(id: '1', index: 1, title: 'Full Movie')];
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    // 1. Cek direct stream cache dari resource link
    final cacheKey = '$seriesId:$episodeId';
    final cached = _streamCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      // 2. Ambil dari play-info (multi-resolusi streams)
      final streams = await _client.fetchPlayInfo(seriesId);
      if (streams.isNotEmpty) {
        // Cari resolusi yang cocok dengan preferensi quality user (misal 720, 1080, 480)
        Map<String, dynamic>? selectedStream;
        if (quality != null && quality.isNotEmpty) {
          final targetQ = quality.replaceAll(RegExp(r'[^0-9]'), '');
          for (final st in streams) {
            final res = '${st['resolutions'] ?? ''}';
            if (res.contains(targetQ)) {
              selectedStream = st;
              break;
            }
          }
        }

        // Fallback: ambil stream dengan resolusi terbaik atau stream pertama
        selectedStream ??= streams.first;
        final url = (selectedStream['url'] as String?)?.trim() ?? '';
        if (url.isNotEmpty) {
          _streamCache[cacheKey] = url;
          return url;
        }
      }

      // 3. Fallback: ambil dari fetchSubjectResource
      final resData = _resourceCache[seriesId] ?? await _client.fetchSubjectResource(seriesId);
      final rawList = resData['list'] as List<dynamic>? ?? [];
      for (final r in rawList) {
        if (r is Map<String, dynamic>) {
          final link = (r['resourceLink'] as String?)?.trim() ?? '';
          if (link.isNotEmpty) {
            _streamCache[cacheKey] = link;
            return link;
          }
        }
      }
    } catch (e) {
      debugPrint('[LivegoDramaSource] streamUrl error: $e');
    }

    return '';
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(String seriesId, String episodeId) async {
    final cacheKey = '$seriesId:$episodeId';
    if (_extrasCache.containsKey(cacheKey)) {
      return _extrasCache[cacheKey];
    }

    try {
      final resData = _resourceCache[seriesId] ?? await _client.fetchSubjectResource(seriesId);
      final rawList = resData['list'] as List<dynamic>? ?? [];

      final subtitles = <DramaSubtitle>[];
      final qualities = <DramaQuality>[];

      // Ambil subtitle dari extCaptions
      if (rawList.isNotEmpty) {
        final item0 = rawList.first;
        if (item0 is Map<String, dynamic>) {
          final captions = item0['extCaptions'] as List<dynamic>? ?? [];
          for (final cap in captions) {
            if (cap is Map<String, dynamic>) {
              final url = (cap['url'] as String?)?.trim() ?? '';
              final lan = (cap['lan'] as String?) ?? 'id';
              final lanName = (cap['lanName'] as String?) ?? 'Indonesian';
              if (url.isNotEmpty) {
                subtitles.add(DramaSubtitle(
                  language: lan,
                  displayName: lanName,
                  url: url,
                ));
              }
            }
          }
        }
      }

      // Ambil daftar resolusi yang tersedia dari play-info
      final streams = await _client.fetchPlayInfo(seriesId);
      for (final st in streams) {
        final res = '${st['resolutions'] ?? ''}';
        if (res.isNotEmpty) {
          qualities.add(DramaQuality(label: '${res}p', resolution: '${res}p'));
        }
      }

      final extras = DramaEpisodeExtras(
        subtitles: subtitles,
        qualities: qualities,
        unlocked: true,
      );
      _extrasCache[cacheKey] = extras;
      return extras;
    } catch (e) {
      debugPrint('[LivegoDramaSource] episodeExtras error: $e');
    }

    return null;
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    try {
      final results = await _client.search(q, page: 1, perPage: 20);
      final items = <ContentItem>[];
      for (final r in results) {
        final sType = (r['subjectType'] as num?)?.toInt() ?? 1;
        // Ambil Movies (1), TV Series (2), Musik (6), Anime (8)
        if (sType != 7) {
          items.add(_mapSubjectToContentItem(r, 'Pencarian'));
        }
      }
      return MovieBoxFilters.stripAdult(_dedupe(items));
    } catch (e) {
      debugPrint('[LivegoDramaSource] search error: $e');
      return const [];
    }
  }

  ContentItem _mapSubjectToContentItem(Map<String, dynamic> json, String category) {
    final id = '${json['subjectId'] ?? json['id'] ?? ''}';
    final title = '${json['title'] ?? json['name'] ?? 'Untitled'}';
    final desc = '${json['description'] ?? json['desc'] ?? ''}';

    String coverUrl = '';
    final cover = json['cover'];
    if (cover is Map<String, dynamic>) {
      coverUrl = (cover['url'] as String?) ?? '';
    } else if (cover is String) {
      coverUrl = cover;
    }

    final epRaw = json['seNum'] ?? json['totalEpisode'] ?? json['episodes'] ?? 1;
    final episodesCount = (epRaw as num?)?.toInt() ?? 1;

    return ContentItem(
      id: id,
      title: title,
      source: 'Livego-drama',
      category: category,
      description: desc,
      posterUrl: coverUrl,
      backdropUrl: coverUrl,
      rating: 8.5,
      episodes: episodesCount,
      platformSlug: slug,
      tags: [category],
    );
  }

  List<ContentItem> _dedupe(List<ContentItem> items) {
    final seen = <String>{};
    final out = <ContentItem>[];
    for (final item in items) {
      if (seen.add(item.id)) out.add(item);
    }
    return out;
  }
}
