import '../core/livego_settings.dart';
import '../models/content_item.dart';
import '../models/stream_info.dart';
import '../services/livego_api_gateway.dart';
import '../services/api/api_platform.dart';
import '../services/cache/livego_content_cache.dart';
import '../services/content/content_health_service.dart';
import '../services/feed/feed_config.dart';
import '../services/feed/feed_limiter.dart';
import '../services/feed/feed_session_state.dart';
import '../services/player/playback_resolver.dart';
import '../models/livego_episode.dart';
import 'api_manager/livego_api_manager.dart';
import 'api_manager/api_timeout_policy.dart';
import 'api_manager/api_platform_fallback_router.dart';
import 'api_manager/api_provider_registry.dart';
import 'mock_catalog.dart';

class LiveGoCatalog {
  static List<String> get platforms {
    final chosen = LiveGoSettings.homePlatforms.where(LiveGoSettings.isPlatformActive).take(6).toList();
    if (chosen.isNotEmpty) return chosen;
    final active = LiveGoSettings.activePlatforms.take(6).toList();
    return active.isEmpty ? LiveGoApiGateway.defaultPlatforms : active;
  }

  static List<String> get allPlatforms => LiveGoApiGateway.supportedPlatforms;
  static List<String> get platformLabels => platforms.map(label).toList();
  static List<String> labelsFor(List<String> values) => values.map(label).toList();
  static List<String> get categories => categoriesFor(platforms.isEmpty ? 'dobda_shortmax' : platforms.first);

  static List<String> categoriesFor(String platform) => LiveGoSettings.categoriesFor(platform).take(6).toList();

  static List<String> availableCategoriesFor(String platform) =>
      LiveGoApiPlatforms.categoriesFor(platform).take(8).toList();

  static List<String> languagesFor(String platform) =>
      LiveGoApiPlatforms.languagesFor(platform);

  static String languageFor(String platform) =>
      LiveGoSettings.languageForPlatform(platform);

  static String backendLabel(String platform) =>
      LiveGoApiPlatforms.backendLabel(platform);

  static bool isDobdaPlatform(String platform) =>
      LiveGoApiPlatforms.bySlug(platform).isDobda;

  static Future<List<String>> fetchCategoriesFor(String platform) async {
    return availableCategoriesFor(platform);
  }

  static Future<String> pingPlatform(String platform) async {
    return LiveGoApiManager.runStatus(
      platform: platform,
      operation: 'ping',
      timeout: ApiTimeoutPolicy.ping,
      request: () => LiveGoApiProviderRegistry.providerFor(platform).ping(languageFor(platform)),
      fallbackStatus: 'offline',
    );
  }

  static Future<List<ContentItem>> _readExpiredItems({
    required String platform,
    required String endpoint,
    required Map<String, String> params,
  }) async {
    final expired = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: endpoint,
      params: params,
      allowExpired: true,
    );
    return ContentHealthService.filterPlayable(expired ?? const <ContentItem>[]);
  }

  static Future<List<ContentItem>> _fallbackHomeFromOtherPlatforms({
    required String preferredPlatform,
    required String operation,
  }) async {
    for (final candidate in ApiPlatformFallbackRouter.fallbackOnly(preferredPlatform, max: 3)) {
      final lang = languageFor(candidate);
      const endpoint = 'home_clean_v2';
      final cached = await _readExpiredItems(
        platform: candidate,
        endpoint: endpoint,
        params: {'lang': lang},
      );
      if (cached.isNotEmpty) {
        print('LIVEGO API FALLBACK $operation $preferredPlatform -> $candidate cached=${cached.length}');
        return cached;
      }

      final rows = await LiveGoApiManager.fetchItems(
        platform: candidate,
        operation: '$operation:fallback:$candidate',
        timeout: ApiTimeoutPolicy.home,
        request: () => LiveGoApiGateway.home(platform: candidate, lang: lang),
      );
      if (rows.isNotEmpty) {
        print('LIVEGO API FALLBACK $operation $preferredPlatform -> $candidate network=${rows.length}');
        await LiveGoContentCache.writeItems(
          platform: candidate,
          endpoint: endpoint,
          params: {'lang': lang},
          items: rows,
        );
        return rows;
      }
    }
    return const <ContentItem>[];
  }

  static Future<List<ContentItem>> home({String platform = 'dobda_shortmax'}) async {
    const endpoint = 'home_clean_v2';
    final lang = languageFor(platform);
    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: endpoint,
      params: {'lang': lang},
      allowExpired: true,
    );
    final cleanCached = ContentHealthService.filterPlayable(cached ?? const <ContentItem>[]);
    if (cleanCached.isNotEmpty) return cleanCached;

    final rows = await LiveGoApiManager.fetchItems(
      platform: platform,
      operation: 'home',
      timeout: ApiTimeoutPolicy.home,
      request: () => LiveGoApiProviderRegistry.providerFor(platform).home(lang: lang),
    );
    print('CATALOG HOME $platform -> ${rows.length}');
    if (rows.isNotEmpty) {
      await LiveGoContentCache.writeItems(
        platform: platform,
        endpoint: endpoint,
        params: {'lang': lang},
        items: rows,
      );
      return rows;
    }

    final discoverRows = await LiveGoApiManager.fetchItems(
      platform: platform,
      operation: 'discover',
      timeout: ApiTimeoutPolicy.home,
      request: () => LiveGoApiProviderRegistry.providerFor(platform).discover(lang: lang),
    );
    if (discoverRows.isNotEmpty) {
      await LiveGoContentCache.writeItems(
        platform: platform,
        endpoint: endpoint,
        params: {'lang': lang},
        items: discoverRows,
      );
      return discoverRows;
    }

    final expired = await _readExpiredItems(
      platform: platform,
      endpoint: endpoint,
      params: {'lang': lang},
    );
    if (expired.isNotEmpty) return expired;

    return _fallbackHomeFromOtherPlatforms(
      preferredPlatform: platform,
      operation: 'home',
    );
  }


  static Future<List<ContentItem>> cachedHomeByCategory({
    String platform = 'dobda_shortmax',
    String category = 'Home',
    bool allowExpired = true,
  }) async {
    final key = LiveGoApiPlatforms.categoryKey(platform, category);
    final endpoint = key.isEmpty ? 'home' : key;
    final lang = languageFor(platform);

    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: endpoint,
      params: {'lang': lang},
      allowExpired: allowExpired,
    );
    final cleanCached = ContentHealthService.filterPlayable(cached ?? const <ContentItem>[]);
    if (cleanCached.isNotEmpty) return cleanCached.take(FeedConfig.itemsPerCategory).toList(growable: false);

    return const <ContentItem>[];
  }

  static Future<List<ContentItem>> homeByCategory({
    String platform = 'dobda_shortmax',
    String category = 'Home',
  }) async {
    final key = LiveGoApiPlatforms.categoryKey(platform, category);
    final endpoint = key.isEmpty ? 'home' : key;
    final lang = languageFor(platform);
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
        return FeedLimiter.prepare(ContentHealthService.filterPlayable(cached), visitSeed: visitSeed);
      }
    }

    final cleanRows = await LiveGoApiManager.fetchItems(
      platform: platform,
      operation: 'category:$endpoint',
      timeout: ApiTimeoutPolicy.collection,
      request: () {
        if (key == 'trending' || key.isEmpty || key == 'home') {
          return LiveGoApiProviderRegistry.providerFor(platform).home(lang: lang);
        }
        return LiveGoApiProviderRegistry.providerFor(platform).collection(
          collection: key,
          lang: lang,
        );
      },
    );
    if (cleanRows.isNotEmpty) {
      FeedSessionState.markNetworkRefresh(sessionKey);
      await LiveGoContentCache.writeItems(
        platform: platform,
        endpoint: endpoint,
        params: {'lang': lang},
        items: cleanRows,
      );
      return FeedLimiter.prepare(cleanRows, visitSeed: visitSeed);
    }

    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: endpoint,
      params: {'lang': lang},
    );
    if (cached != null && cached.isNotEmpty) {
      return FeedLimiter.prepare(ContentHealthService.filterPlayable(cached), visitSeed: visitSeed);
    }

    final rows = ContentHealthService.filterPlayable(await home(platform: platform));
    if (rows.isNotEmpty) {
      await LiveGoContentCache.writeItems(
        platform: platform,
        endpoint: endpoint,
        params: {'lang': lang},
        items: rows,
      );
      return FeedLimiter.prepare(rows, visitSeed: visitSeed);
    }

    final fallbackRows = await _fallbackHomeFromOtherPlatforms(
      preferredPlatform: platform,
      operation: 'category:$endpoint',
    );
    return FeedLimiter.prepare(fallbackRows, visitSeed: visitSeed);
  }

  static Future<Map<String, List<ContentItem>>> homeSections() async {
    await LiveGoContentCache.cleanExpiredAndTrim();
    final entries = <MapEntry<String, List<ContentItem>>>[];
    final seenKeys = <String>{};
    for (final platform in platforms.take(6)) {
      final rows = await home(platform: platform);
      final clean = <ContentItem>[];
      for (final item in rows) {
        final key = ContentHealthService.contentKey(item);
        if (seenKeys.add(key)) clean.add(item);
      }
      if (clean.isNotEmpty) entries.add(MapEntry(label(platform), clean));
    }
    return Map.fromEntries(entries);
  }

  static Future<List<ContentItem>> banners({String platform = 'dobda_shortmax'}) async {
    final items = await home(platform: platform);
    if (items.isNotEmpty) return items.take(5).toList();
    return [];
  }

  static Future<ContentItem> hero({String platform = 'dobda_shortmax'}) async {
    try {
      final items = await home(platform: platform);
      if (items.isNotEmpty) return items.first;
    } catch (e) { print('LIVEGO CATALOG ERROR: $e'); }
    return MockCatalog.hero;
  }

  static Future<List<ContentItem>> search(String query, {String platform = 'dobda_shortmax'}) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: 'search',
      params: {'q': clean, 'lang': languageFor(platform)},
    );
    if (cached != null) return ContentHealthService.filterPlayable(cached);
    final lang = languageFor(platform);
    final cleanRows = await LiveGoApiManager.fetchItems(
      platform: platform,
      operation: 'search',
      timeout: ApiTimeoutPolicy.search,
      request: () => LiveGoApiProviderRegistry.providerFor(platform).search(query: clean, lang: lang),
    );
    await LiveGoContentCache.writeItems(
      platform: platform,
      endpoint: 'search',
      params: {'q': clean, 'lang': lang},
      items: cleanRows,
      ttl: LiveGoContentCache.searchTtl,
    );
    if (cleanRows.isNotEmpty) return cleanRows;

    final expired = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: 'search',
      params: {'q': clean, 'lang': lang},
      allowExpired: true,
    );
    return ContentHealthService.filterPlayable(expired ?? const <ContentItem>[]);
  }

  static Future<List<ContentItem>> searchAll(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    final merged = <ContentItem>[];
    final seen = <String>{};
    void mergeRows(List<ContentItem> rows) {
      for (final item in ContentHealthService.filterPlayable(rows)) {
        final key = ContentHealthService.contentKey(item);
        if (seen.add(key)) merged.add(item);
      }
    }

    for (final platform in platforms) {
      if (LiveGoApiManager.isInCooldown(platform) && merged.isNotEmpty) continue;
      mergeRows(await search(clean, platform: platform));
    }

    if (merged.isEmpty) {
      for (final platform in ApiPlatformFallbackRouter.candidates(platforms.isEmpty ? 'dobda_shortmax' : platforms.first, max: 5)) {
        if (platforms.contains(platform)) continue;
        mergeRows(await search(clean, platform: platform));
        if (merged.isNotEmpty) break;
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
    final detail = await LiveGoApiManager.fetchDetail(
      item: item,
      request: () => LiveGoApiProviderRegistry.providerFor(item.platformSlug).detail(item),
      fallback: item,
    );
    final resolved = _preservePlayableIdentity(detail ?? item, item);
    await LiveGoContentCache.writeDetail(resolved);
    return resolved;
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


  static Future<List<LiveGoEpisode>> episodes(ContentItem item) async {
    final cached = await LiveGoContentCache.readEpisodes(item);

    // Older fast-start builds could cache a synthetic fallback containing only
    // Episode 1 before /detail finished. Do not trust a single-row episode
    // cache for providers that normally expose a full episode list; refresh it
    // from the active LiveGo source so the player sheet shows all episodes again.
    if (cached != null && cached.length > 1) return cached;

    final rows = await LiveGoApiManager.fetchEpisodes(
      item: item,
      request: () => LiveGoApiProviderRegistry.providerFor(item.platformSlug).episodes(item),
      fallback: cached ?? const <LiveGoEpisode>[],
    );
    if (rows.length > 1) {
      await LiveGoContentCache.writeEpisodes(item, rows);
      return rows;
    }

    // If the network still cannot provide the full list, only then fall back
    // to the old cached single episode or item.episodes. Never overwrite a
    // good future cache with this one-row fallback.
    if (cached != null && cached.isNotEmpty) return cached;
    if (rows.isNotEmpty) return rows;

    final total = item.episodes <= 0 ? 1 : item.episodes;
    return List.generate(total, (i) => LiveGoEpisode(id: '${i + 1}', index: i + 1, title: 'Episode ${i + 1}'));
  }

  static Future<int> episodeCount(ContentItem item) async {
    final rows = await episodes(item);
    return rows.isEmpty ? (item.episodes <= 0 ? 1 : item.episodes) : rows.length;
  }

  static Future<StreamInfo> streamInfo(ContentItem item, {String? chapterId}) async {
    return LiveGoApiManager.fetchStreamInfo(
      item: item,
      timeout: ApiTimeoutPolicy.video,
      request: () => PlaybackResolver.resolveStreamInfo(item, chapterId: chapterId ?? item.chapterId),
    );
  }

  static Future<StreamInfo> fastStreamInfo(
    ContentItem item, {
    String? chapterId,
    Duration? timeout,
  }) async {
    return LiveGoApiManager.fetchStreamInfo(
      item: item,
      timeout: timeout ?? const Duration(seconds: 6),
      request: () => PlaybackResolver.fastStreamInfo(
        item,
        chapterId: chapterId ?? item.chapterId,
        timeout: timeout ?? const Duration(seconds: 6),
      ),
    );
  }

  static Future<String> videoUrl(ContentItem item) async {
    final info = await streamInfo(item, chapterId: item.chapterId);
    return info.url;
  }

  static String label(String slug) {
    final config = LiveGoApiPlatforms.bySlugOrNull(slug);
    if (config != null) return config.name;
    return slug
        .split(RegExp(r'[_-]'))
        .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }
}
