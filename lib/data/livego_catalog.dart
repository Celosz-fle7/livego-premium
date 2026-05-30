import '../core/livego_settings.dart';
import '../models/content_item.dart';
import '../models/stream_info.dart';
import '../services/anichin_api_client.dart';
import '../services/cache/livego_content_cache.dart';
import '../services/feed/feed_config.dart';
import '../services/feed/feed_limiter.dart';
import '../services/feed/feed_session_state.dart';
import '../models/livego_episode.dart';
import 'mock_catalog.dart';

class LiveGoCatalog {
  static List<String> get platforms {
    final chosen = LiveGoSettings.homePlatforms.where(LiveGoSettings.isPlatformActive).take(6).toList();
    if (chosen.isNotEmpty) return chosen;
    final active = LiveGoSettings.activePlatforms.take(6).toList();
    return active.isEmpty ? AnichinApiClient.defaultPlatforms : active;
  }

  static List<String> get allPlatforms => AnichinApiClient.supportedPlatforms;
  static List<String> get platformLabels => platforms.map(label).toList();
  static List<String> labelsFor(List<String> values) => values.map(label).toList();
  static List<String> get categories => categoriesFor(platforms.isEmpty ? 'shortmax' : platforms.first);

  static List<String> categoriesFor(String platform) => LiveGoSettings.categoriesFor(platform).take(6).toList();

  static Future<List<String>> fetchCategoriesFor(String platform) async {
    return categoriesFor(platform);
  }

  static Future<String> pingPlatform(String platform) async {
    final start = DateTime.now();
    try {
      final rows = await AnichinApiClient.home(platform: platform, lang: LiveGoSettings.language);
      if (rows.isEmpty) {
        LiveGoSettings.setPlatformStatus(platform, 'offline');
        return 'offline';
      }
      final ms = DateTime.now().difference(start).inMilliseconds;
      final status = ms > 2500 ? 'slow' : 'online';
      LiveGoSettings.setPlatformStatus(platform, status);
      return status;
    } catch (e) {
      print('LIVEGO PING ERROR $platform: $e');
      LiveGoSettings.setPlatformStatus(platform, 'offline');
      return 'offline';
    }
  }

  static Future<List<ContentItem>> home({String platform = 'shortmax'}) async {
    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: 'home',
      params: {'lang': LiveGoSettings.language},
    );
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final rows = await AnichinApiClient.home(platform: platform, lang: LiveGoSettings.language)
          .timeout(const Duration(seconds: 12));
      print('CATALOG HOME $platform -> ${rows.length}');
      if (rows.isNotEmpty) {
        await LiveGoContentCache.writeItems(
          platform: platform,
          endpoint: 'home',
          params: {'lang': LiveGoSettings.language},
          items: rows,
        );
        return rows;
      }
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }

    try {
      final rows = await AnichinApiClient.discover(platform: platform, lang: LiveGoSettings.language)
          .timeout(const Duration(seconds: 12));
      if (rows.isNotEmpty) {
        await LiveGoContentCache.writeItems(
          platform: platform,
          endpoint: 'home',
          params: {'lang': LiveGoSettings.language},
          items: rows,
        );
        return rows;
      }
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }

    return [];
  }


  static Future<List<ContentItem>> homeByCategory({
    String platform = 'shortmax',
    String category = 'Trending',
  }) async {
    final key = category.trim().toLowerCase().replaceAll(' ', '');
    final endpoint = key.isEmpty ? 'home' : key;
    final lang = LiveGoSettings.language;
    final sessionKey = FeedSessionState.key(platform, endpoint, lang: lang);
    final visitSeed = FeedSessionState.markVisited(sessionKey);
    final shouldRefresh = FeedSessionState.shouldRefresh(
      sessionKey,
      FeedConfig.activeRefreshInterval,
    );

    if (!shouldRefresh) {
      final cached = await LiveGoContentCache.readItems(
        platform: platform,
        endpoint: endpoint,
        params: {'lang': lang},
      );
      if (cached != null && cached.isNotEmpty) {
        return FeedLimiter.prepare(cached, visitSeed: visitSeed);
      }
    }

    try {
      List<ContentItem> rows = const <ContentItem>[];
      if (key == 'foryou') {
        rows = await AnichinApiClient.discover(platform: platform, lang: lang)
            .timeout(const Duration(seconds: 12));
      } else if (platform == 'dramabox' && (key == 'latest' || key == 'vip' || key == 'dubindo')) {
        rows = await AnichinApiClient.collection(
          platform: platform,
          collection: key,
          lang: lang,
        ).timeout(const Duration(seconds: 12));
      } else {
        rows = await AnichinApiClient.home(platform: platform, lang: lang)
            .timeout(const Duration(seconds: 12));
      }

      if (rows.isNotEmpty) {
        FeedSessionState.markNetworkRefresh(sessionKey);
        await LiveGoContentCache.writeItems(
          platform: platform,
          endpoint: endpoint,
          params: {'lang': lang},
          items: rows,
        );
        return FeedLimiter.prepare(rows, visitSeed: visitSeed);
      }
    } catch (e) { print('LIVEGO CATEGORY ERROR: $e'); }

    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: endpoint,
      params: {'lang': lang},
    );
    if (cached != null && cached.isNotEmpty) {
      return FeedLimiter.prepare(cached, visitSeed: visitSeed);
    }

    final rows = await home(platform: platform);
    if (rows.isNotEmpty) {
      await LiveGoContentCache.writeItems(
        platform: platform,
        endpoint: endpoint,
        params: {'lang': lang},
        items: rows,
      );
    }
    return FeedLimiter.prepare(rows, visitSeed: visitSeed);
  }

  static Future<Map<String, List<ContentItem>>> homeSections() async {
    await LiveGoContentCache.cleanExpiredAndTrim();
    final futures = platforms.take(6).map((platform) async {
      final rows = await home(platform: platform);
      return MapEntry(label(platform), rows);
    });
    final entries = await Future.wait(futures);
    return Map.fromEntries(entries.where((e) => e.value.isNotEmpty));
  }

  static Future<List<ContentItem>> banners({String platform = 'shortmax'}) async {
    final items = await home(platform: platform);
    if (items.isNotEmpty) return items.take(5).toList();
    return [];
  }

  static Future<ContentItem> hero({String platform = 'shortmax'}) async {
    try {
      final items = await home(platform: platform);
      if (items.isNotEmpty) return items.first;
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }
    return MockCatalog.hero;
  }

  static Future<List<ContentItem>> search(String query, {String platform = 'shortmax'}) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: 'search',
      params: {'q': clean, 'lang': LiveGoSettings.language},
    );
    if (cached != null) return cached;
    try {
      final rows = await AnichinApiClient.search(query: clean, platform: platform, lang: LiveGoSettings.language);
      await LiveGoContentCache.writeItems(
        platform: platform,
        endpoint: 'search',
        params: {'q': clean, 'lang': LiveGoSettings.language},
        items: rows,
        ttl: LiveGoContentCache.searchTtl,
      );
      return rows;
    } catch (e) {
      print('LIVEGO SEARCH ERROR: $e');
      return [];
    }
  }

  static Future<List<ContentItem>> searchAll(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    final merged = <ContentItem>[];
    final seen = <String>{};
    for (final platform in platforms) {
      final rows = await search(clean, platform: platform);
      for (final item in rows) {
        final key = '${item.platformSlug}:${item.id}';
        if (seen.add(key)) merged.add(item);
      }
    }
    return merged;
  }

  static Future<ContentItem> detail(ContentItem item) async {
    final cached = await LiveGoContentCache.readDetail(item);
    if (cached != null) {
      final resolvedCached = _preservePlayableIdentity(cached, item);
      if (resolvedCached.id.isNotEmpty) return resolvedCached;
    }
    try {
      final detail = await AnichinApiClient.detail(item);
      final resolved = _preservePlayableIdentity(detail ?? item, item);
      await LiveGoContentCache.writeDetail(resolved);
      return resolved;
    } catch (e) {
      print('LIVEGO DETAIL ERROR: $e');
      return item;
    }
  }

  static ContentItem _preservePlayableIdentity(ContentItem detail, ContentItem original) {
    return ContentItem(
      id: detail.id.trim().isNotEmpty ? detail.id : original.id,
      title: detail.title.trim().isNotEmpty ? detail.title : original.title,
      source: detail.source.trim().isNotEmpty ? detail.source : original.source,
      category: detail.category.trim().isNotEmpty ? detail.category : original.category,
      description: detail.description.trim().isNotEmpty ? detail.description : original.description,
      posterUrl: detail.posterUrl.trim().isNotEmpty ? detail.posterUrl : original.posterUrl,
      backdropUrl: detail.backdropUrl.trim().isNotEmpty ? detail.backdropUrl : original.backdropUrl,
      rating: detail.rating,
      episodes: detail.episodes > 0 ? detail.episodes : original.episodes,
      updated: detail.updated || original.updated,
      platformSlug: detail.platformSlug.trim().isNotEmpty ? detail.platformSlug : original.platformSlug,
      chapterId: detail.chapterId.trim().isNotEmpty ? detail.chapterId : original.chapterId,
      lang: detail.lang.trim().isNotEmpty ? detail.lang : original.lang,
    );
  }



  static Future<List<LiveGoEpisode>?> cachedEpisodes(ContentItem item) async {
    final cached = await LiveGoContentCache.readEpisodes(item);
    if (cached == null || cached.length <= 1) return null;
    return cached;
  }

  static Future<List<LiveGoEpisode>> episodes(ContentItem item) async {
    final cached = await LiveGoContentCache.readEpisodes(item);

    // Older fast-start builds could cache a synthetic fallback containing only
    // Episode 1 before /allepisode finished. Do not trust a single-row episode
    // cache for providers that normally expose a full episode list; refresh it
    // from Anichin so the player sheet shows all episodes again.
    if (cached != null && cached.length > 1) return cached;

    try {
      final rows = await AnichinApiClient.episodes(item).timeout(const Duration(seconds: 12));
      if (rows.length > 1) {
        await LiveGoContentCache.writeEpisodes(item, rows);
        return rows;
      }

      // If the network still cannot provide the full list, only then fall back
      // to the old cached single episode or item.episodes. Never overwrite a
      // good future cache with this one-row fallback.
      if (cached != null && cached.isNotEmpty) return cached;
      if (rows.isNotEmpty) return rows;
    } catch (e) {
      print('LIVEGO EPISODES ERROR: $e');
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final total = item.episodes <= 0 ? 1 : item.episodes;
    return List.generate(total, (i) => LiveGoEpisode(id: '${i + 1}', index: i + 1, title: 'Episode ${i + 1}'));
  }

  static Future<int> episodeCount(ContentItem item) async {
    final rows = await episodes(item);
    return rows.isEmpty ? (item.episodes <= 0 ? 1 : item.episodes) : rows.length;
  }

  static Future<StreamInfo> streamInfo(ContentItem item, {String? chapterId}) async {
    try {
      return await AnichinApiClient.videoInfo(item, chapterId: chapterId ?? item.chapterId);
    } catch (e) {
      print('LIVEGO STREAM ERROR: $e');
      return StreamInfo.empty;
    }
  }

  static Future<String> videoUrl(ContentItem item) async {
    final info = await streamInfo(item, chapterId: item.chapterId);
    return info.url;
  }

  static String label(String slug) {
    return slug
        .split(RegExp(r'[_-]'))
        .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }
}
