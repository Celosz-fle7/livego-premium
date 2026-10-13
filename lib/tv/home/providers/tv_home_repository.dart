import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/livego_catalog.dart';
import '../../../models/content_item.dart';
import '../../../services/cache/livego_content_cache.dart';
import '../../../services/content/content_health_service.dart';
import '../../../services/drama_source.dart';
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

  /// Hanya filter konten playable. TIDAK ada cap jumlah lagi — cap 28 lama
  /// diganti pagination bertahap (halaman per halaman, ikut server).
  List<ContentItem> _prepareItems(List<ContentItem> rows) {
    return ContentHealthService.filterPlayable(rows).toList(growable: false);
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
    required int pageSize,
  }) async {
    final List<ContentItem> cached;
    if (DramaSourceRegistry.handles(platform)) {
      // Sumber drama eksternal: baca disk cache (ditulis saat loadNetwork).
      cached = await LiveGoContentCache.readItems(
        platform: platform,
        endpoint: 'home',
        params: {'category': selectedCategory},
      ).timeout(
        TvHomePerformanceConfig.cacheReadTimeout,
        onTimeout: () => null,
      ) ?? const <ContentItem>[];
    } else {
      cached = await LiveGoCatalog.cachedHomeByCategory(
        platform: platform,
        category: selectedCategory,
        allowExpired: false,
      ).timeout(
        TvHomePerformanceConfig.cacheReadTimeout,
        onTimeout: () => const <ContentItem>[],
      );
    }

    final prepared = _prepareItems(cached);
    if (prepared.isEmpty) return null;

    // Disk cache hanya menyimpan halaman 1. Heuristik hasMore: halaman
    // penuh -> kemungkinan masih ada; halaman parsial -> habis.
    return TvHomeContentState(
      hero: prepared.first,
      items: prepared,
      loading: false,
      refreshing: true,
      fromCache: true,
      page: 1,
      hasMore: prepared.length >= pageSize,
    );
  }

  /// Halaman 1 dari server (ikut server, bukan load semua).
  Future<TvHomeContentState?> loadNetwork({
    required String platform,
    required String selectedCategory,
    required int pageSize,
  }) async {
    final List<ContentItem> items;
    final bool hasMore;
    final dramaSource = DramaSourceRegistry.forSlug(platform);
    if (dramaSource != null) {
      // Sumber drama eksternal (multi-APK): satu halaman via registry.
      final res = await dramaSource
          .homePage(selectedCategory, page: 1, pageSize: pageSize)
          .timeout(
            TvHomePerformanceConfig.foregroundNetworkTimeout,
            onTimeout: () => (items: const <ContentItem>[], hasMore: false),
          );
      items = res.items;
      hasMore = res.hasMore;
      // Tulis disk cache biar tidak request ulang terus (ala Netflix/MovieBox).
      if (items.isNotEmpty) {
        unawaited(
          LiveGoContentCache.writeItems(
            platform: platform,
            endpoint: 'home',
            params: {'category': selectedCategory},
            items: items,
          ),
        );
      }
    } else {
      items = await LiveGoCatalog.homeByCategory(
        platform: platform,
        category: selectedCategory,
      ).timeout(
        TvHomePerformanceConfig.foregroundNetworkTimeout,
        onTimeout: () => const <ContentItem>[],
      );
      hasMore = false;
    }

    final prepared = _prepareItems(items);
    if (prepared.isEmpty) return null;

    return TvHomeContentState(
      hero: prepared.first,
      items: prepared,
      loading: false,
      page: 1,
      hasMore: hasMore,
    );
  }

  /// Halaman berikutnya (dipicu scroll masuk zona lookahead).
  /// Return null kalau request gagal — pemanggil mempertahankan hasMore
  /// supaya bisa retry di trigger berikutnya.
  Future<({List<ContentItem> items, bool hasMore})?> loadNetworkPage({
    required String platform,
    required String category,
    required int page,
    required int pageSize,
  }) async {
    try {
      final dramaSource = DramaSourceRegistry.forSlug(platform);
      if (dramaSource != null) {
        final res = await dramaSource
            .homePage(category, page: page, pageSize: pageSize)
            .timeout(TvHomePerformanceConfig.foregroundNetworkTimeout);
        final prepared = _prepareItems(res.items);
        return (items: prepared, hasMore: res.hasMore);
      }
      final all = await LiveGoCatalog.homeByCategory(
        platform: platform,
        category: category,
      ).timeout(TvHomePerformanceConfig.foregroundNetworkTimeout);
      final prepared = _prepareItems(all);
      final start = (page - 1) * pageSize;
      if (start >= prepared.length) return (items: const <ContentItem>[], hasMore: false);
      final end = (start + pageSize).clamp(0, prepared.length);
      return (
        items: prepared.sublist(start, end),
        hasMore: end < prepared.length,
      );
    } catch (_) {
      return null;
    }
  }

  Future<TvHomeContentState?> loadFallbackCache({
    required String platform,
    required String selectedCategory,
    required int pageSize,
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
      page: 1,
      hasMore: prepared.length >= pageSize,
    );
  }

  /// Refresh halaman 1 di background (SWR): ganti state dengan data fresh.
  Future<TvHomeContentState?> refresh(
    String platform,
    String selectedCategory, {
    required int pageSize,
  }) async {
    final List<ContentItem> fresh;
    final bool hasMore;
    final dramaSource = DramaSourceRegistry.forSlug(platform);
    if (dramaSource != null) {
      final res = await dramaSource
          .homePage(selectedCategory, page: 1, pageSize: pageSize)
          .timeout(
            TvHomePerformanceConfig.backgroundRefreshTimeout,
            onTimeout: () => (items: const <ContentItem>[], hasMore: false),
          );
      fresh = res.items;
      hasMore = res.hasMore;
    } else {
      fresh = await LiveGoCatalog.homeByCategory(
        platform: platform,
        category: selectedCategory,
      ).timeout(
        TvHomePerformanceConfig.backgroundRefreshTimeout,
        onTimeout: () => const <ContentItem>[],
      );
      hasMore = false;
    }

    final prepared = _prepareItems(fresh);
    if (prepared.isEmpty) {
      debugPrint('TV HOME BACKGROUND REFRESH EMPTY platform=$platform category=$selectedCategory');
      return null;
    }

    return TvHomeContentState(
      hero: prepared.first,
      items: prepared,
      loading: false,
      page: 1,
      hasMore: hasMore,
    );
  }
}
