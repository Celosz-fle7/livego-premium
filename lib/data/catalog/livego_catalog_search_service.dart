import '../../models/content_item.dart';
import '../../services/cache/livego_content_cache.dart';
import '../../services/content/content_health_service.dart';
import '../api_manager/api_platform_fallback_router.dart';
import '../api_manager/api_provider_registry.dart';
import '../api_manager/api_timeout_policy.dart';
import '../api_manager/livego_api_manager.dart';
import 'livego_catalog_platform_service.dart';

class LiveGoCatalogSearchService {
  const LiveGoCatalogSearchService._();

  static Future<List<ContentItem>> search(String query, {String platform = 'nobuzero_freereels'}) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    final cached = await LiveGoContentCache.readItems(
      platform: platform,
      endpoint: 'search',
      params: {'q': clean, 'lang': LiveGoCatalogPlatformService.languageFor(platform)},
    );
    if (cached != null) return ContentHealthService.filterPlayable(cached);

    final lang = LiveGoCatalogPlatformService.languageFor(platform);
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

    for (final platform in LiveGoCatalogPlatformService.platforms) {
      if (LiveGoApiManager.isInCooldown(platform) && merged.isNotEmpty) continue;
      mergeRows(await search(clean, platform: platform));
    }

    if (merged.isEmpty) {
      final first = LiveGoCatalogPlatformService.platforms.isEmpty
          ? 'nobuzero_freereels'
          : LiveGoCatalogPlatformService.platforms.first;
      for (final platform in ApiPlatformFallbackRouter.candidates(first, max: 5)) {
        if (LiveGoCatalogPlatformService.platforms.contains(platform)) continue;
        mergeRows(await search(clean, platform: platform));
        if (merged.isNotEmpty) break;
      }
    }

    return merged;
  }
}
