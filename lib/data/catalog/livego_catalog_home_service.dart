import '../../services/api/api_platform.dart';
import '../../models/content_item.dart';
import '../../services/cache/livego_content_cache.dart';
import '../../services/content/content_health_service.dart';
import '../../services/feed/feed_config.dart';
import '../../services/feed/feed_limiter.dart';
import '../../services/feed/feed_session_state.dart';
import '../../services/livego_api_gateway.dart';
import '../api_manager/api_platform_fallback_router.dart';
import '../api_manager/api_provider_registry.dart';
import '../api_manager/api_timeout_policy.dart';
import '../api_manager/livego_api_manager.dart';
import '../mock_catalog.dart';
import 'livego_catalog_platform_service.dart';

class LiveGoCatalogHomeService {
  const LiveGoCatalogHomeService._();

  static Duration _homeCategoryTtl(String endpoint) {
    final key = endpoint.trim().toLowerCase();
    if (key == 'livego') return FeedConfig.liveGoRecommendationTtl;
    if (key == 'home' || key == 'home_clean_v2') return FeedConfig.homeApiTtl;
    return FeedConfig.hardHomeCacheTtl;
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
      final lang = LiveGoCatalogPlatformService.languageFor(candidate);
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
          ttl: _homeCategoryTtl(endpoint),
        );
        return rows;
      }
    }
    return const <ContentItem>[];
  }

  static Future<List<ContentItem>> home({String platform = 'dobda_shortmax'}) async {
    const endpoint = 'home_clean_v2';
    final lang = LiveGoCatalogPlatformService.languageFor(platform);
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
    if (rows.isNotEmpty) {
      await LiveGoContentCache.writeItems(
        platform: platform,
        endpoint: endpoint,
        params: {'lang': lang},
        items: rows,
        ttl: _homeCategoryTtl(endpoint),
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
        ttl: _homeCategoryTtl(endpoint),
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
    final lang = LiveGoCatalogPlatformService.languageFor(platform);

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
    final lang = LiveGoCatalogPlatformService.languageFor(platform);
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
        // Mapping Home/Trending -> .home()
        if (key == 'trending' || key.isEmpty || key == 'home') {
          return LiveGoApiProviderRegistry.providerFor(platform).home(lang: lang);
        }
        // Mapping Terbaru/Discover -> .discover()
        if (key == 'discover') {
          return LiveGoApiProviderRegistry.providerFor(platform).discover(lang: lang);
        }
        // Mapping LiveGo/DubIndo -> .collection(collection: 'livego')
        if (key == 'livego') {
          return LiveGoApiProviderRegistry.providerFor(platform).collection(
            collection: 'livego',
            lang: lang,
          );
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
        ttl: _homeCategoryTtl(endpoint),
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
        ttl: _homeCategoryTtl(endpoint),
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
    // Tetap ambil maksimal 6 platform di Home TV agar device aman.
    for (final platform in LiveGoCatalogPlatformService.platforms.take(6)) {
      final rows = await home(platform: platform);
      final clean = <ContentItem>[];
      for (final item in rows) {
        final key = ContentHealthService.contentKey(item);
        if (seenKeys.add(key)) clean.add(item);
      }
      if (clean.isNotEmpty) entries.add(MapEntry(LiveGoCatalogPlatformService.label(platform), clean));
    }
    return Map.fromEntries(entries);
  }

  static Future<List<ContentItem>> banners({String platform = 'dobda_shortmax'}) async {
    final lang = LiveGoCatalogPlatformService.languageFor(platform);
    try {
      // Banner API dengan timeout pendek (6 detik).
      final rows = await LiveGoApiGateway.banner(platform: platform, lang: lang)
          .timeout(const Duration(seconds: 6));
      if (rows.isNotEmpty) return rows.take(5).toList();
    } catch (e) {
      print('BANNER API ERROR $platform: $e');
    }

    // Fallback: ambil dari item Home jika banner endpoint gagal.
    final items = await home(platform: platform);
    if (items.isNotEmpty) return items.take(5).toList();
    return const [];
  }

  static Future<ContentItem> hero({String platform = 'dobda_shortmax'}) async {
    try {
      final items = await banners(platform: platform);
      if (items.isNotEmpty) return items.first;
    } catch (e) {
      print('LIVEGO CATALOG HERO ERROR: $e');
    }
    return MockCatalog.hero;
  }
}
