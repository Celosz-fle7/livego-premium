import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'moviebox_client.dart';
import 'moviebox_filters.dart';

/// Adapter Provider Livego (MovieBox Short TV / Micro-drama vertikal episode 1-100).
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
  String get label => 'Livego';

  @override
  List<String> get categories => const [
        'Paling Trending',
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

    // Penanganan khusus Paling Trending (menggunakan list terpanas master & search rank)
    if (normCat.contains('paling') || normCat == 'paling trending') {
      try {
        final listRes = await _client.fetchSubjectList(
          subjectType: 7,
          sort: 'Terpanas',
          page: 1,
          perPage: 30,
        );
        final items = listRes.items
            .map((s) => _mapShortToContentItem(s, 'Paling Trending'))
            .where((item) => item.id.isNotEmpty)
            .toList();

        final hotRanks = await _client.fetchSearchRank();
        for (final cat in hotRanks) {
          if ((cat['name'] as String?)?.toLowerCase().contains('short') == true) {
            final rawItems = cat['items'] as List<dynamic>? ?? [];
            for (final it in rawItems) {
              if (it is Map<String, dynamic>) {
                items.add(_mapShortToContentItem(it, 'Paling Trending'));
              }
            }
          }
        }

        final deduped = _dedupe(MovieBoxFilters.stripAdult(items));
        if (deduped.isNotEmpty) {
          _categoryCache['paling trending'] = deduped;
          return deduped;
        }
      } catch (e) {
        debugPrint('[MovieBoxSource] paling trending error: $e');
      }
    }

    try {
      // Ambil feed tab 13 (Short TV section resmi)
      final data = await _client.fetchTabOperating(13);
      final rawItems = data['items'] as List<dynamic>? ?? [];

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

        final cleanItems = _dedupe(MovieBoxFilters.stripAdult(items));
        _categoryCache[title.toLowerCase()] = cleanItems;
      }

      for (final entry in _categoryCache.entries) {
        if (entry.key == normCat ||
            entry.key.contains(normCat) ||
            normCat.contains(entry.key)) {
          return entry.value;
        }
      }

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
    final normCat = category.trim().toLowerCase();
    if (normCat.contains('paling') || normCat == 'paling trending') {
      try {
        final listRes = await _client.fetchSubjectList(
          subjectType: 7,
          sort: 'Terpanas',
          page: page,
          perPage: pageSize,
        );
        final items = _dedupe(MovieBoxFilters.stripAdult(
          listRes.items
              .map((s) => _mapShortToContentItem(s, 'Paling Trending'))
              .where((item) => item.id.isNotEmpty)
              .toList(),
        ));
        return (items: items, hasMore: listRes.hasMore);
      } catch (e) {
        debugPrint('[MovieBoxSource] homePage paling trending error: $e');
      }
    }

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
      // 1. Ambil detail info drama untuk jumlah total episode
      final info = await _client.fetchShortInfo(seriesId);
      final totalEpRaw = info['totalEpisode'] ?? info['total'];
      final totalEp = (totalEpRaw as num?)?.toInt() ?? 60;

      // 2. Ambil 20 episode pertama secara instan (server membatasi range maks 20 per request)
      final rawEpisodes = await _client.fetchShortEpisodes(seriesId, startPosition: 1, endPosition: 20);
      final list = <LiveGoEpisode>[];

      for (var i = 0; i < rawEpisodes.length; i++) {
        final epData = rawEpisodes[i];
        final miniId = '${epData['miniId'] ?? epData['id'] ?? ''}';
        final epNum = (epData['ep'] as num?)?.toInt() ?? (i + 1);
        final title = 'Episode $epNum';

        if (miniId.isNotEmpty) {
          list.add(LiveGoEpisode(id: miniId, index: epNum, title: title));

          final videoMap = epData['video'] as Map<String, dynamic>?;
          final addrMap = videoMap?['videoAddress'] as Map<String, dynamic>?;
          final url = (addrMap?['url'] as String?)?.trim() ?? '';
          if (url.isNotEmpty) {
            _streamCache['$seriesId:$miniId'] = url;
            _streamCache['$seriesId:$epNum'] = url;
            _streamCache['$seriesId:ep_$epNum'] = url;
          }
        }
      }

      // 3. Tambahkan sisa episode jika total > 20 sebagai stub agar episode picker lengkap
      if (list.isNotEmpty && totalEp > list.length) {
        for (var i = list.length + 1; i <= totalEp; i++) {
          list.add(LiveGoEpisode(id: '$i', index: i, title: 'Episode $i'));
        }
      }

      if (list.isNotEmpty) {
        _episodesCache[seriesId] = list;
        return list;
      }
    } catch (e) {
      debugPrint('[MovieBoxSource] episodes error: $e');
    }

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
      // Coba parse nomor episode (misal "1", "25", atau "ep_25")
      final epNum = int.tryParse(episodeId.replaceAll(RegExp(r'[^0-9]'), ''));
      if (epNum != null && epNum > 0 && epNum <= 200) {
        final start = ((epNum - 1) ~/ 20) * 20 + 1;
        final end = start + 19;
        final pageEpisodes = await _client.fetchShortEpisodes(seriesId, startPosition: start, endPosition: end);
        for (var i = 0; i < pageEpisodes.length; i++) {
          final epData = pageEpisodes[i];
          final miniId = '${epData['miniId'] ?? epData['id'] ?? ''}';
          final epNo = (epData['ep'] as num?)?.toInt() ?? (start + i);
          final videoMap = epData['video'] as Map<String, dynamic>?;
          final addrMap = videoMap?['videoAddress'] as Map<String, dynamic>?;
          final url = (addrMap?['url'] as String?)?.trim() ?? '';
          if (url.isNotEmpty) {
            _streamCache['$seriesId:$miniId'] = url;
            _streamCache['$seriesId:$epNo'] = url;
            _streamCache['$seriesId:ep_$epNo'] = url;
          }
        }
      } else {
        await episodes(seriesId);
      }

      final refetched = _streamCache[cacheKey] ??
          (epNum != null ? _streamCache['$seriesId:$epNum'] : null) ??
          _streamCache['$seriesId:1'];
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

  List<ContentItem> _dedupe(List<ContentItem> items) {
    final seen = <String>{};
    final result = <ContentItem>[];
    for (final it in items) {
      if (it.id.isNotEmpty && seen.add(it.id)) {
        result.add(it);
      }
    }
    return result;
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
      source: 'Livego',
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
