import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'moviebox_client.dart';
import 'moviebox_filters.dart';

/// Adapter Provider MovieBox Short TV (Micro-drama vertikal episode 1-100).
/// Mengambil data dari section Short TV (Tab 13) dan streaming langsung dari GoodShort/Vskit CDN.
class MovieBoxSource implements DramaSource {
  final MovieBoxClient _client = MovieBoxClient.instance;

  /// Cache category -> list ContentItem
  final Map<String, List<ContentItem>> _categoryCache = {};

  /// Cache episode direct stream url: "$seriesId:$episodeId" -> streamUrl
  final Map<String, String> _streamCache = {};

  /// Cache daftar episode per seriesId
  final Map<String, List<LiveGoEpisode>> _episodesCache = {};

  MovieBoxClient get client => _client;

  @override
  String get slug => 'moviebox';

  @override
  String get label => 'Short TV';

  @override
  List<String> get categories => const [
        'Sedang Trending',
        'Terbaru',
        'Tokoh Legendaris',
        'Animasi',
        'CEO',
        '😈Balas Dendam',
        '💖Cerita Barat',
        '🎧Drama Dubbing',
        '🇮🇩Lokal Short TV',
      ];

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    final normCat = category.trim().toLowerCase();
    if (_categoryCache.containsKey(normCat) && _categoryCache[normCat]!.isNotEmpty) {
      return _categoryCache[normCat]!;
    }

    try {
      // Ambil feed tab 13 (Short TV section resmi)
      final data = await _client.fetchTabOperating(13);
      final rawItems = data['items'] as List<dynamic>? ?? [];

      // Isi semua cache kategori dari response yang didapat sekaligus
      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) continue;
        final title = (raw['title'] as String?)?.trim() ?? '';
        final subjects = raw['subjects'] as List<dynamic>? ?? [];
        if (subjects.isEmpty) continue;

        final items = subjects
            .whereType<Map<String, dynamic>>()
            .map((s) => _mapShortToContentItem(s, title))
            .where((item) => item.id.isNotEmpty)
            .toList();

        final cleanItems = MovieBoxFilters.stripAdult(items);
        _categoryCache[title.toLowerCase()] = cleanItems;
      }

      // Cari kategori yang cocok
      for (final entry in _categoryCache.entries) {
        if (entry.key == normCat ||
            entry.key.contains(normCat) ||
            normCat.contains(entry.key)) {
          return entry.value;
        }
      }

      // Fallback: kembalikan item dari section pertama jika tidak ketemu persis
      if (_categoryCache.isNotEmpty) {
        return _categoryCache.values.first;
      }
    } catch (e, stack) {
      debugPrint('[MovieBoxSource] homeByCategory error: $e\n$stack');
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
    _streamCache.clear();
    _episodesCache.clear();
  }

  @override
  Future<DramaEpisodeExtras?> episodeExtras(
    String seriesId,
    String episodeId,
  ) async {
    return const DramaEpisodeExtras(
      unlocked: true,
      episodePrice: 0,
    );
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    final cached = _episodesCache[seriesId];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      // Ambil hingga 100 episode pertama
      final rawEpisodes = await _client.fetchShortEpisodes(seriesId, startPosition: 1, endPosition: 100);
      if (rawEpisodes.isNotEmpty) {
        final list = <LiveGoEpisode>[];
        for (var i = 0; i < rawEpisodes.length; i++) {
          final epData = rawEpisodes[i];
          final miniId = '${epData['miniId'] ?? epData['id'] ?? ''}';
          final epNum = (epData['ep'] as num?)?.toInt() ?? (i + 1);
          final title = 'Episode $epNum';

          if (miniId.isNotEmpty) {
            list.add(LiveGoEpisode(id: miniId, index: epNum, title: title));

            // Simpan stream url ke cache
            final videoMap = epData['video'] as Map<String, dynamic>?;
            final addrMap = videoMap?['videoAddress'] as Map<String, dynamic>?;
            final url = (addrMap?['url'] as String?)?.trim() ?? '';
            if (url.isNotEmpty) {
              _streamCache['$seriesId:$miniId'] = url;
            }
          }
        }

        if (list.isNotEmpty) {
          _episodesCache[seriesId] = list;
          return list;
        }
      }
    } catch (e) {
      debugPrint('[MovieBoxSource] episodes error: $e');
    }

    // Fallback minimal jika gagal network
    return [LiveGoEpisode(id: seriesId, index: 1, title: 'Episode 1')];
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final cacheKey = '$seriesId:$episodeId';
    final cached = _streamCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      // Refresh daftar episode untuk mendapatkan stream URL
      await episodes(seriesId);
      final refetched = _streamCache[cacheKey];
      if (refetched != null && refetched.isNotEmpty) return refetched;
    } catch (e) {
      debugPrint('[MovieBoxSource] streamUrl error: $e');
    }

    return '';
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    try {
      final results = await _client.search(q, page: 1, perPage: 20);
      final items = <ContentItem>[];
      for (final r in results) {
        // Ambil Short TV (subjectType == 7) atau item dengan cover valid
        final sType = (r['subjectType'] as num?)?.toInt() ?? 0;
        if (sType == 7 || sType == 0) {
          items.add(_mapShortToContentItem(r, 'Pencarian'));
        }
      }
      return MovieBoxFilters.stripAdult(items);
    } catch (e) {
      debugPrint('[MovieBoxSource] search error: $e');
      return const [];
    }
  }

  ContentItem _mapShortToContentItem(Map<String, dynamic> json, String category) {
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

    final epRaw = json['totalEpisode'] ?? json['episodes'] ?? json['total'];
    final episodesCount = (epRaw as num?)?.toInt() ?? 60;

    return ContentItem(
      id: id,
      title: title,
      source: 'MovieBox',
      category: category,
      description: desc,
      posterUrl: coverUrl,
      backdropUrl: coverUrl,
      rating: 8.8,
      episodes: episodesCount,
      platformSlug: slug,
      tags: [category],
    );
  }
}
