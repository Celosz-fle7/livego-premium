import 'package:flutter/foundation.dart';

import '../../../data/livego_catalog.dart';
import '../../../models/content_item.dart';
import '../../../services/content/content_health_service.dart';
import '../../../services/network/livego_network_status.dart';
import '../../cache/tv_ram_cache.dart';
import '../tv_home_performance_config.dart';
import 'tv_home_content_state.dart';

/// Home data repository.
///
/// This class owns cache/network/fallback/background-refresh work.
/// The provider/controller only decides which state should be shown.
class TvHomeRepository {
  const TvHomeRepository();

  static const int maxTvHomeItems = TvHomePerformanceConfig.maxManifestItems;

  String homeContentKey({
    required String platform,
    required String category,
    int page = 1,
    Object? paramsHash,
  }) {
    return TvRamCache.key('home', [
      platform,
      category,
      page,
      paramsHash ?? 'default',
    ]);
  }

  List<ContentItem> _prepareItems(List<ContentItem> rows) {
    return ContentHealthService.filterPlayable(rows)
        .take(maxTvHomeItems)
        .toList(growable: false);
  }

  TvHomeContentState? readRam(String cacheKey) {
    return TvRamCache.instance.read<TvHomeContentState>(cacheKey);
  }

  void saveRam(String cacheKey, TvHomeContentState state) {
    if (state.items.isEmpty) return;
    TvRamCache.instance.write(
      cacheKey,
      state,
      ttl: TvRamCache.homeTtl,
    );
  }

  TvHomeContentState asRefreshingCache(TvHomeContentState state) {
    return state.copyWith(
      loading: false,
      refreshing: true,
      hasError: false,
      fromCache: true,
      offline: false,
    );
  }

  Future<bool> isOnline() => LiveGoNetworkStatus.isProbablyOnline();

  void markOnline() => LiveGoNetworkStatus.markOnline();

  void markOffline() => LiveGoNetworkStatus.markOffline();

  Future<TvHomeContentState?> loadCached({
    required String platform,
    required String selectedCategory,
  }) async {
    final cached = await LiveGoCatalog.cachedHomeByCategory(
      platform: platform,
      category: selectedCategory,
      allowExpired: false,
    ).timeout(
      TvHomePerformanceConfig.cacheReadTimeout,
      onTimeout: () => const <ContentItem>[],
    );

    final prepared = _prepareItems(cached);
    if (prepared.isEmpty) return null;

    return TvHomeContentState(
      hero: prepared.first,
      items: prepared,
      loading: false,
      refreshing: true,
      fromCache: true,
    );
  }

  Future<TvHomeContentState?> loadNetwork({
    required String platform,
    required String selectedCategory,
  }) async {
    final items = await LiveGoCatalog.homeByCategory(
      platform: platform,
      category: selectedCategory,
    ).timeout(
      TvHomePerformanceConfig.foregroundNetworkTimeout,
      onTimeout: () => const <ContentItem>[],
    );

    final prepared = _prepareItems(items);
    if (prepared.isEmpty) return null;

    return TvHomeContentState(
      hero: prepared.first,
      items: prepared,
      loading: false,
    );
  }

  Future<TvHomeContentState?> loadFallbackCache({
    required String platform,
    required String selectedCategory,
  }) async {
    final fallback = await LiveGoCatalog.cachedHomeByCategory(
      platform: platform,
      category: selectedCategory,
      allowExpired: true,
    ).timeout(
      TvHomePerformanceConfig.fallbackCacheTimeout,
      onTimeout: () => const <ContentItem>[],
    );

    final prepared = _prepareItems(fallback);
    if (prepared.isEmpty) return null;

    return TvHomeContentState(
      hero: prepared.first,
      items: prepared,
      loading: false,
      hasError: true,
      fromCache: true,
    );
  }

  Future<TvHomeContentState?> refresh(String platform, String selectedCategory) async {
    final fresh = await LiveGoCatalog.homeByCategory(
      platform: platform,
      category: selectedCategory,
    ).timeout(
      TvHomePerformanceConfig.backgroundRefreshTimeout,
      onTimeout: () => const <ContentItem>[],
    );

    final prepared = _prepareItems(fresh);
    if (prepared.isEmpty) {
      debugPrint('TV HOME BACKGROUND REFRESH EMPTY platform=$platform category=$selectedCategory');
      return null;
    }

    return TvHomeContentState(
      hero: prepared.first,
      items: prepared,
      loading: false,
    );
  }
}
