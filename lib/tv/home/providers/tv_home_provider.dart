import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/livego_catalog.dart';
import '../../../models/content_item.dart';
import '../../../services/content/content_health_service.dart';
import '../../../services/network/livego_network_status.dart';
import '../../cache/tv_ram_cache.dart';

/// Cache-first TV Home content state.
///
/// Provider responsibility:
/// - Home data
/// - loading / refreshing / error / fromCache
/// - retry and cache-first loading through LiveGoCatalog
///
/// This replaces the old FutureBuilder-wrapped Home body. Data refresh now lives
/// in Riverpod, so Home can rebuild from one stable state object and focus
/// movement no longer recreates FutureBuilder work.
class TvHomeContentState {
  final ContentItem? hero;
  final List<ContentItem> items;
  final bool loading;
  final bool refreshing;
  final bool hasError;
  final bool fromCache;
  final bool offline;

  const TvHomeContentState({
    this.hero,
    this.items = const <ContentItem>[],
    this.loading = true,
    this.refreshing = false,
    this.hasError = false,
    this.fromCache = false,
    this.offline = false,
  });

  TvHomeContentState copyWith({
    ContentItem? hero,
    List<ContentItem>? items,
    bool? loading,
    bool? refreshing,
    bool? hasError,
    bool? fromCache,
    bool? offline,
  }) {
    return TvHomeContentState(
      hero: hero ?? this.hero,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      hasError: hasError ?? this.hasError,
      fromCache: fromCache ?? this.fromCache,
      offline: offline ?? this.offline,
    );
  }
}

/// ARCHITECTURE LOCK:
/// This controller owns Home data/loading/error/retry/cache state only.
/// Focus index and TV zones stay in `tv_home_focus_state.dart`.
/// Key handling and BACK ladder stay in `tv_home_interaction_controller.dart`.
/// UI layout stays in `tv_home_screen.dart`.
class TvHomeContentController extends StateNotifier<TvHomeContentState> {
  TvHomeContentController() : super(const TvHomeContentState());

  static const int _maxTvHomeItems = 30;

  int _loadToken = 0;
  TvHomeContentState? _lastGoodState;
  String _lastPlatform = 'dobda_freereels';
  String _lastCategory = 'Home';

  List<ContentItem> _prepareItems(List<ContentItem> rows) {
    return ContentHealthService.filterPlayable(rows)
        .take(_maxTvHomeItems)
        .toList(growable: false);
  }

  Future<void> load({
    required String platform,
    required String selectedCategory,
    bool clearPrevious = false,
  }) async {
    _lastPlatform = platform;
    _lastCategory = selectedCategory;
    final token = ++_loadToken;
    final ramKey = TvRamCache.key('home', [platform, selectedCategory]);
    final ramState = clearPrevious ? null : TvRamCache.instance.read<TvHomeContentState>(ramKey);
    if (ramState != null && ramState.items.isNotEmpty) {
      final next = ramState.copyWith(
        loading: false,
        refreshing: true,
        hasError: false,
        fromCache: true,
        offline: false,
      );
      _lastGoodState = next;
      state = next;
    } else if (clearPrevious) {
      state = const TvHomeContentState(loading: true);
    } else if (state.items.isEmpty) {
      state = state.copyWith(loading: true, refreshing: false, hasError: false, offline: false);
    } else {
      state = state.copyWith(refreshing: true, hasError: false, offline: false);
    }

    final online = await LiveGoNetworkStatus.isProbablyOnline();
    if (token != _loadToken) return;
    if (!online) {
      final last = _lastGoodState;
      if (last != null) {
        state = last.copyWith(
          loading: false,
          refreshing: false,
          hasError: true,
          fromCache: true,
          offline: true,
        );
      } else {
        state = const TvHomeContentState(
          loading: false,
          hasError: true,
          fromCache: false,
          offline: true,
        );
      }
      return;
    }

    try {
      final cached = await LiveGoCatalog.cachedHomeByCategory(
        platform: platform,
        category: selectedCategory,
        allowExpired: true,
      ).timeout(const Duration(milliseconds: 650), onTimeout: () => const <ContentItem>[]);

      if (token != _loadToken) return;
      final prepared = _prepareItems(cached);
      if (prepared.isNotEmpty) {
        final next = TvHomeContentState(
          hero: prepared.first,
          items: prepared,
          loading: false,
          refreshing: true,
          fromCache: true,
        );
        _lastGoodState = next;
        TvRamCache.instance.write(ramKey, next, ttl: TvRamCache.homeTtl);
        state = next;
        unawaited(_refreshInBackground(platform, selectedCategory, token));
        return;
      }
    } catch (e) {
      debugPrint('TV HOME CACHE LOAD ERROR: $e');
    }

    try {
      final items = await LiveGoCatalog.homeByCategory(
        platform: platform,
        category: selectedCategory,
      ).timeout(const Duration(seconds: 10), onTimeout: () => const <ContentItem>[]);

      if (token != _loadToken) return;
      final prepared = _prepareItems(items);
      if (prepared.isNotEmpty) {
        LiveGoNetworkStatus.markOnline();
        final next = TvHomeContentState(hero: prepared.first, items: prepared, loading: false);
        _lastGoodState = next;
        TvRamCache.instance.write(ramKey, next, ttl: TvRamCache.homeTtl);
        state = next;
        return;
      }
    } catch (e) {
      debugPrint('TV HOME NETWORK LOAD ERROR: $e');
    }

    try {
      final fallback = await LiveGoCatalog.cachedHomeByCategory(
        platform: platform,
        category: selectedCategory,
        allowExpired: true,
      ).timeout(const Duration(milliseconds: 800), onTimeout: () => const <ContentItem>[]);

      if (token != _loadToken) return;
      final prepared = _prepareItems(fallback);
      if (prepared.isNotEmpty) {
        final next = TvHomeContentState(
          hero: prepared.first,
          items: prepared,
          loading: false,
          hasError: true,
          fromCache: true,
        );
        _lastGoodState = next;
        TvRamCache.instance.write(ramKey, next, ttl: TvRamCache.homeTtl);
        state = next;
        return;
      }
    } catch (_) {}

    if (token != _loadToken) return;
    final last = _lastGoodState;
    if (last != null) {
      LiveGoNetworkStatus.markOffline();
      state = last.copyWith(loading: false, refreshing: false, hasError: true, offline: true);
    } else {
      LiveGoNetworkStatus.markOffline();
      state = const TvHomeContentState(loading: false, hasError: true, offline: true);
    }
  }

  Future<void> retry() {
    return load(
      platform: _lastPlatform,
      selectedCategory: _lastCategory,
      clearPrevious: false,
    );
  }

  Future<void> _refreshInBackground(String platform, String selectedCategory, int token) async {
    try {
      final fresh = await LiveGoCatalog.homeByCategory(
        platform: platform,
        category: selectedCategory,
      ).timeout(const Duration(seconds: 12), onTimeout: () => const <ContentItem>[]);

      if (token != _loadToken) return;
      if (fresh.isEmpty) {
        final last = _lastGoodState;
        if (last != null) {
          final next = last.copyWith(refreshing: false, hasError: true);
          _lastGoodState = next;
          state = next;
        }
        return;
      }

      LiveGoNetworkStatus.markOnline();
      final prepared = _prepareItems(fresh);
      if (prepared.isEmpty) return;
      final next = TvHomeContentState(hero: prepared.first, items: prepared, loading: false);
      _lastGoodState = next;
      TvRamCache.instance.write(
        TvRamCache.key('home', [platform, selectedCategory]),
        next,
        ttl: TvRamCache.homeTtl,
      );
      state = next;
    } catch (e) {
      debugPrint('TV HOME BACKGROUND REFRESH ERROR: $e');
      if (token != _loadToken) return;
      final last = _lastGoodState;
      if (last == null) return;
      final next = last.copyWith(refreshing: false, hasError: true);
      _lastGoodState = next;
      state = next;
    }
  }
}

final tvHomeContentProvider = StateNotifierProvider<TvHomeContentController, TvHomeContentState>(
  (ref) => TvHomeContentController(),
);
