import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';

/// Home UI selection state. This state is intentionally separated from Home
/// content so focus/selection changes do not force a network/data rebuild.
class TvHomeUiState {
  final int platformIndex;
  final int categoryIndex;
  final int gridIndex;

  const TvHomeUiState({
    this.platformIndex = 0,
    this.categoryIndex = 0,
    this.gridIndex = 0,
  });

  TvHomeUiState copyWith({int? platformIndex, int? categoryIndex, int? gridIndex}) {
    return TvHomeUiState(
      platformIndex: platformIndex ?? this.platformIndex,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      gridIndex: gridIndex ?? this.gridIndex,
    );
  }
}

class TvHomeController extends StateNotifier<TvHomeUiState> {
  TvHomeController() : super(const TvHomeUiState());

  void rememberPlatform(int index) => state = state.copyWith(platformIndex: index);
  void rememberCategory(int index) => state = state.copyWith(categoryIndex: index);
  void rememberGrid(int index) => state = state.copyWith(gridIndex: index);
}

final tvHomeProvider = StateNotifierProvider<TvHomeController, TvHomeUiState>(
  (ref) => TvHomeController(),
);

/// Cache-first TV Home content state.
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

  const TvHomeContentState({
    this.hero,
    this.items = const <ContentItem>[],
    this.loading = true,
    this.refreshing = false,
    this.hasError = false,
    this.fromCache = false,
  });

  TvHomeContentState copyWith({
    ContentItem? hero,
    List<ContentItem>? items,
    bool? loading,
    bool? refreshing,
    bool? hasError,
    bool? fromCache,
  }) {
    return TvHomeContentState(
      hero: hero ?? this.hero,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      hasError: hasError ?? this.hasError,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class TvHomeContentController extends StateNotifier<TvHomeContentState> {
  TvHomeContentController() : super(const TvHomeContentState());

  int _loadToken = 0;
  TvHomeContentState? _lastGoodState;

  Future<void> load({
    required String platform,
    required String selectedCategory,
    bool clearPrevious = false,
  }) async {
    final token = ++_loadToken;
    if (clearPrevious) {
      state = const TvHomeContentState(loading: true);
    } else if (state.items.isEmpty) {
      state = state.copyWith(loading: true, refreshing: false, hasError: false);
    } else {
      state = state.copyWith(refreshing: true, hasError: false);
    }

    try {
      final cached = await LiveGoCatalog.cachedHomeByCategory(
        platform: platform,
        category: selectedCategory,
        allowExpired: true,
      ).timeout(const Duration(milliseconds: 650), onTimeout: () => const <ContentItem>[]);

      if (token != _loadToken) return;
      if (cached.isNotEmpty) {
        final next = TvHomeContentState(
          hero: cached.first,
          items: cached,
          loading: false,
          refreshing: true,
          fromCache: true,
        );
        _lastGoodState = next;
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
      if (items.isNotEmpty) {
        final next = TvHomeContentState(hero: items.first, items: items, loading: false);
        _lastGoodState = next;
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
      if (fallback.isNotEmpty) {
        final next = TvHomeContentState(
          hero: fallback.first,
          items: fallback,
          loading: false,
          hasError: true,
          fromCache: true,
        );
        _lastGoodState = next;
        state = next;
        return;
      }
    } catch (_) {}

    if (token != _loadToken) return;
    final last = _lastGoodState;
    if (last != null) {
      state = last.copyWith(loading: false, refreshing: false, hasError: true);
    } else {
      state = const TvHomeContentState(loading: false, hasError: true);
    }
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

      final next = TvHomeContentState(hero: fresh.first, items: fresh, loading: false);
      _lastGoodState = next;
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
