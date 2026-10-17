import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../drama_source.dart';
import 'moviebox_client.dart';
import 'moviebox_filters.dart';
import 'moviebox_shorttv_seed.dart';

/// Implementasi DramaSource untuk provider MovieBox / OneRoom.
class MovieBoxSource implements DramaSource {
  final MovieBoxClient _client = MovieBoxClient();

  /// Cache daftar kategori -> List ContentItem.
  final Map<String, List<ContentItem>> _categoryItemsCache = {};

  /// Cache subjectId -> detail map dari server MovieBox.
  final Map<String, Map<String, dynamic>> _detailCache = {};

  /// Cache episode direct stream url: "$seriesId:$episodeId" -> streamUrl.
  final Map<String, String> _streamCache = {};

  MovieBoxClient get client => _client;

  @override
  String get slug => 'moviebox';

  @override
  String get label => 'MovieBox';

  @override
  List<String> get categories => const [
        // Tab ShortTV Internal
        'Sedang Trending',
        'Terbaru',
        'Balas Dendam',
        'Cerita Barat',
        'Drama Dubbing',
        'Lokal Short TV',
        'Animasi',
        // Kategori Film & Drama Utama
        '🔥Hot Short TV',
        'Trending Drama🔥',
        'Trending Indonesian Drama💗',
        'Trending Indonesian Movies',
        'Trending Movies',
        'K-Drama: New Release',
        'Indonesian Horror Stories 💀',
        'Free Now 🎉',
        'Into Animeverse🌟',
        'Thai-Drama',
        'Trending Indo Dubbed',
        'Action & Crime 👊',
        '100% LOVE 💗',
        'Family Time🏡',
      ];

  @override
  Future<List<ContentItem>> homeByCategory(String category) async {
    final normCat = _normalizeCategory(category);
    if (_categoryItemsCache.containsKey(normCat)) {
      return _categoryItemsCache[normCat]!;
    }

    // 1. Cek apakah kategori ada di Seed ShortTV Internal (Disewa Jadi Pengasuh, Putri yang Kembali, dll)
    for (final entry in MovieBoxShortTvSeed.categories.entries) {
      if (_normalizeCategory(entry.key) == normCat) {
        final items = entry.value.map((m) {
          final id = '${m['id']}';
          final title = '${m['title']}';
          final cover = '${m['cover']}';
          final ep = (m['totalEpisode'] as num?)?.toInt() ?? 1;
          final genre = '${m['genre'] ?? entry.key}';
          return ContentItem(
            id: id,
            title: title,
            source: 'MovieBox',
            category: genre,
            description: '',
            posterUrl: cover,
            backdropUrl: cover,
            rating: 8.5,
            episodes: ep,
            platformSlug: slug,
            tags: [genre],
          );
        }).toList();

        final clean = MovieBoxFilters.stripAdult(items);
        _categoryItemsCache[normCat] = clean;
        return clean;
      }
    }

    // 2. Ambil dari H5 Gateway live feed (tab-operating)
    final data = await _client.fetchTabOperating(tabCode: 'HOME');
    final operatingList = data['operatingList'] as List<dynamic>? ?? [];

    for (final op in operatingList) {
      if (op is! Map<String, dynamic>) continue;
      final title = (op['title'] as String? ?? '').trim();
      final subjects = op['subjects'] as List<dynamic>? ?? [];
      if (subjects.isEmpty) continue;

      final items = <ContentItem>[];
      for (final s in subjects) {
        if (s is! Map<String, dynamic>) continue;
        final item = _parseContentItem(s, defaultCategory: title);
        if (item != null) {
          items.add(item);
        }
      }

      final opNorm = _normalizeCategory(title);
      _categoryItemsCache[opNorm] = MovieBoxFilters.stripAdult(items);
    }

    return _categoryItemsCache[normCat] ??
        _categoryItemsCache[_normalizeCategory('Sedang Trending')] ??
        _categoryItemsCache[_normalizeCategory('🔥Hot Short TV')] ??
        const [];
  }

  @override
  Future<({List<ContentItem> items, bool hasMore})> homePage(
    String category, {
    int page = 1,
    int pageSize = 30,
  }) async {
    final all = await homeByCategory(category);
    if (page > 1) {
      return (items: const <ContentItem>[], hasMore: false);
    }
    return (items: all, hasMore: false);
  }

  @override
  Future<List<LiveGoEpisode>> episodes(String seriesId) async {
    // 1. Cek apakah ada di MovieBoxShortTvSeed untuk mendapatkan total episode asli
    int totalEp = 1;
    for (final list in MovieBoxShortTvSeed.categories.values) {
      for (final item in list) {
        if ('${item['id']}' == seriesId) {
          totalEp = (item['totalEpisode'] as num?)?.toInt() ?? 1;
          break;
        }
      }
      if (totalEp > 1) break;
    }

    // 2. Jika bukan ShortTV seed, coba ambil dari detail cache MovieBox
    if (totalEp <= 1) {
      var detail = _detailCache[seriesId];
      if (detail == null) {
        detail = await _client.fetchDetail(seriesId);
        if (detail.isNotEmpty) {
          _detailCache[seriesId] = detail;
        }
      }

      final resource = detail?['resource'] as Map<String, dynamic>?;
      if (resource != null) {
        final seasons = resource['seasons'] as List<dynamic>?;
        if (seasons != null && seasons.isNotEmpty) {
          final s0 = seasons[0] as Map<String, dynamic>?;
          totalEp = (s0?['maxEp'] as num?)?.toInt() ?? 1;
        }
      }
    }

    if (totalEp <= 0) totalEp = 1;

    final cachedStream = _streamCache['$seriesId:1'];
    final epList = <LiveGoEpisode>[];
    for (var i = 1; i <= totalEp; i++) {
      epList.add(LiveGoEpisode(
        id: '$i',
        index: i,
        title: 'Episode $i',
      ));
      if (i == 1 && cachedStream != null && cachedStream.isNotEmpty) {
        _streamCache['$seriesId:$i'] = cachedStream;
      }
    }

    return epList;
  }

  @override
  Future<String> streamUrl({
    required String seriesId,
    required String episodeId,
    String? quality,
  }) async {
    final cacheKey = '$seriesId:$episodeId';
    if (_streamCache.containsKey(cacheKey) && _streamCache[cacheKey]!.isNotEmpty) {
      return _streamCache[cacheKey]!;
    }

    // Ambil direct video dari trailer jika episode 1
    var detail = _detailCache[seriesId];
    if (detail == null) {
      detail = await _client.fetchDetail(seriesId);
      if (detail.isNotEmpty) {
        _detailCache[seriesId] = detail;
      }
    }

    final subject = detail['subject'] as Map<String, dynamic>?;
    final trailer = subject?['trailer'] as Map<String, dynamic>?;
    final vAddr = trailer?['videoAddress'] as Map<String, dynamic>?;
    final url = (vAddr?['url'] as String? ?? '').trim();

    if (url.isNotEmpty) {
      _streamCache[cacheKey] = url;
      return url;
    }

    return '';
  }

  @override
  Future<List<ContentItem>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    // Pastikan data seed dan gateway sudah terisi
    if (_categoryItemsCache.isEmpty) {
      await homeByCategory('Sedang Trending');
      await homeByCategory('🔥Hot Short TV');
    }

    final matched = <ContentItem>[];
    final seenIds = <String>{};

    for (final items in _categoryItemsCache.values) {
      for (final item in items) {
        if (!seenIds.contains(item.id)) {
          if (item.title.toLowerCase().contains(q) ||
              item.description.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q)) {
            seenIds.add(item.id);
            matched.add(item);
          }
        }
      }
    }

    return MovieBoxFilters.stripAdult(matched);
  }

  @override
  Future<void> signOut() async {
    _streamCache.clear();
    _categoryItemsCache.clear();
    _detailCache.clear();
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

  ContentItem? _parseContentItem(
    Map<String, dynamic> json, {
    required String defaultCategory,
  }) {
    final subjectId = '${json['subjectId'] ?? ''}';
    if (subjectId.isEmpty || subjectId == '0') return null;

    final title = (json['title'] as String? ?? 'Untitled').trim();
    final description = (json['description'] as String? ?? '').trim();
    final genre = (json['genre'] as String? ?? '').trim();
    final country = (json['countryName'] as String? ?? '').trim();

    final cover = json['cover'] as Map<String, dynamic>?;
    final posterUrl = (cover?['url'] as String? ?? '').trim();

    final trailer = json['trailer'] as Map<String, dynamic>?;
    final vAddr = trailer?['videoAddress'] as Map<String, dynamic>?;
    final videoUrl = (vAddr?['url'] as String? ?? '').trim();
    if (videoUrl.isNotEmpty) {
      _streamCache['$subjectId:1'] = videoUrl;
    }

    final ratingRaw = json['imdbRatingValue'];
    final rating = double.tryParse('$ratingRaw') ?? 8.0;

    return ContentItem(
      id: subjectId,
      title: title,
      source: 'MovieBox',
      category: genre.isNotEmpty ? genre.split(',').first.trim() : defaultCategory,
      description: description,
      posterUrl: posterUrl,
      backdropUrl: posterUrl,
      rating: rating,
      episodes: 1,
      platformSlug: slug,
      // Tag genre + negara dipakai matcher filter (kata kunci/genre).
      tags: [
        ...genre.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
        if (country.isNotEmpty) country,
      ],
    );
  }

  String _normalizeCategory(String cat) {
    return cat.trim().toLowerCase();
  }
}
