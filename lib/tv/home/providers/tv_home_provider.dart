import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tv_home_content_state.dart';
import 'tv_home_repository.dart';

/// ARCHITECTURE LOCK:
/// This controller owns Home data/loading/error/retry state only.
/// Focus index and TV zones stay in `tv_home_focus_state.dart`.
/// Key handling and BACK ladder stay in `tv_home_interaction_controller.dart`.
/// UI layout stays in `tv_home_screen.dart`.
class TvHomeContentController extends StateNotifier<TvHomeContentState> {
  TvHomeContentController({
    TvHomeRepository repository = const TvHomeRepository(),
  })  : _repository = repository,
        super(const TvHomeContentState());

  final TvHomeRepository _repository;

  int _loadToken = 0;
  TvHomeContentState? _lastGoodState;
  String _lastPlatform = 'dobda_freereels';
  String _lastCategory = 'Home';

  Future<void> load({
    required String platform,
    required String selectedCategory,
    bool clearPrevious = false,
  }) async {
    _lastPlatform = platform;
    _lastCategory = selectedCategory;
    final token = ++_loadToken;

    // Even when the UI asks to clear previous content, show matching RAM cache
    // immediately if the same platform/category was already loaded before.
    // This prevents category/platform switching from feeling like first launch.
    final ramState = _repository.readRam(platform, selectedCategory);
    if (ramState != null && ramState.items.isNotEmpty) {
      final next = _repository.asRefreshingCache(ramState);
      _lastGoodState = next;
      state = next;
    } else if (clearPrevious) {
      state = const TvHomeContentState(loading: true);
    } else if (state.items.isEmpty) {
      state = state.copyWith(loading: true, refreshing: false, hasError: false, offline: false);
    } else {
      state = state.copyWith(refreshing: true, hasError: false, offline: false);
    }

    try {
      final cached = await _repository.loadCached(platform, selectedCategory);
      if (!_active(token)) return;
      if (cached != null && cached.items.isNotEmpty) {
        _remember(platform, selectedCategory, cached);
        state = cached;
        unawaited(_refreshInBackground(platform, selectedCategory, token));
        return;
      }
    } catch (error) {
      debugPrint('TV HOME CACHE LOAD ERROR: $error');
    }

    final online = await _repository.isOnline();
    if (!_active(token)) return;
    if (!online) {
      _showOffline();
      return;
    }

    try {
      final network = await _repository.loadNetwork(platform, selectedCategory);
      if (!_active(token)) return;
      if (network != null && network.items.isNotEmpty) {
        _repository.markOnline();
        _remember(platform, selectedCategory, network);
        state = network;
        return;
      }
    } catch (error) {
      debugPrint('TV HOME NETWORK LOAD ERROR: $error');
    }

    try {
      final fallback = await _repository.loadFallbackCache(platform, selectedCategory);
      if (!_active(token)) return;
      if (fallback != null && fallback.items.isNotEmpty) {
        _remember(platform, selectedCategory, fallback);
        state = fallback;
        return;
      }
    } catch (error) {
      debugPrint('TV HOME FALLBACK CACHE ERROR: $error');
    }

    if (!_active(token)) return;
    _showOffline();
  }

  Future<void> retry() {
    return load(
      platform: _lastPlatform,
      selectedCategory: _lastCategory,
      clearPrevious: false,
    );
  }

  bool _active(int token) => token == _loadToken;

  void _remember(String platform, String selectedCategory, TvHomeContentState next) {
    _lastGoodState = next;
    _repository.saveRam(platform, selectedCategory, next);
  }

  void _showOffline() {
    final last = _lastGoodState;
    _repository.markOffline();
    if (last != null) {
      state = last.copyWith(
        loading: false,
        refreshing: false,
        hasError: true,
        fromCache: true,
        offline: true,
      );
      return;
    }

    state = const TvHomeContentState(
      loading: false,
      hasError: true,
      fromCache: false,
      offline: true,
    );
  }

  Future<void> _refreshInBackground(String platform, String selectedCategory, int token) async {
    try {
      final fresh = await _repository.refresh(platform, selectedCategory);
      if (!_active(token)) return;

      if (fresh == null || fresh.items.isEmpty) {
        final last = _lastGoodState;
        if (last != null) {
          final next = last.copyWith(refreshing: false, hasError: true);
          _lastGoodState = next;
          state = next;
        }
        return;
      }

      _repository.markOnline();
      _remember(platform, selectedCategory, fresh);
      state = fresh;
    } catch (error) {
      debugPrint('TV HOME BACKGROUND REFRESH ERROR: $error');
      if (!_active(token)) return;
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
