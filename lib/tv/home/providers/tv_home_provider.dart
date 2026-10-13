import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/livego_settings.dart';
import '../../../services/drama_source.dart';
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
  String _lastPlatform = 'melolo';
  String _lastCategory = 'Home';
  String? _requestedKey;
  String? _displayedKey;
  String _loadingMode = 'firstLoad';

  String? get requestedKey => _requestedKey;
  String? get displayedKey => _displayedKey;
  String get loadingMode => _loadingMode;

  /// Ukuran request satu halaman TV: 2 baris (2 × jumlah kolom grid).
  /// = 14 konten saat kolom 7 — layar pertama penuh 2 baris, baris ke-3
  /// tidak lagi terlihat separuh. Server boleh mengembalikan
  /// lebih/sedikit — diterima apa adanya.
  int get _pageSize =>
      LiveGoSettings.tvHomeGrid.clamp(7, 10).toInt() * 2;

  Future<void> load({
    required String platform,
    required String selectedCategory,
    bool clearPrevious = false,
  }) async {
    _lastPlatform = platform;
    _lastCategory = selectedCategory;
    final requestKey = _repository.homeContentKey(
      platform: platform,
      category: selectedCategory,
      page: 1,
    );
    _requestedKey = requestKey;
    final token = ++_loadToken;

    // Even when the UI asks to clear previous content, show matching RAM cache
    // immediately if the same platform/category/page/params key was loaded before.
    // This prevents category/platform switching from feeling like first launch.
    final ramState = _repository.readRam(requestKey);
    if (ramState != null && ramState.items.isNotEmpty) {
      _loadingMode = 'cachedHit';
      final next = _repository.asRefreshingCache(ramState);
      _remember(requestKey, next);
      state = next;
    } else if (clearPrevious && state.items.isNotEmpty) {
      _loadingMode = 'refreshingOldData';
      state = state.copyWith(
        loading: false,
        refreshing: true,
        hasError: false,
        offline: false,
        page: 1,
        hasMore: true,
        loadingMore: false,
      );
    } else if (clearPrevious) {
      _loadingMode = 'firstLoad';
      state = const TvHomeContentState(loading: true);
    } else if (state.items.isEmpty) {
      _loadingMode = 'firstLoad';
      state = state.copyWith(
        loading: true,
        refreshing: false,
        hasError: false,
        offline: false,
        page: 1,
        hasMore: true,
        loadingMore: false,
      );
    } else {
      _loadingMode = 'refreshingOldData';
      state = state.copyWith(
        refreshing: true,
        hasError: false,
        offline: false,
        loadingMore: false,
      );
    }

    try {
      final cached = await _repository.loadCached(
        platform: platform,
        selectedCategory: selectedCategory,
        pageSize: _pageSize,
      );
      if (!_active(token, requestKey)) return;
      if (cached != null && cached.items.isNotEmpty) {
        _loadingMode = 'cachedHit';
        _remember(requestKey, cached);
        state = cached;
        unawaited(_refreshInBackground(platform, selectedCategory, requestKey, token));
        return;
      }
    } catch (error) {
      debugPrint('TV HOME CACHE LOAD ERROR: $error');
    }

    try {
      final network = await _repository.loadNetwork(
        platform: platform,
        selectedCategory: selectedCategory,
        pageSize: _pageSize,
      );
      if (!_active(token, requestKey)) return;
      if (network != null && network.items.isNotEmpty) {
        _loadingMode = 'loaded';
        _repository.markOnline();
        _remember(requestKey, network);
        state = network;
        return;
      }
    } catch (error) {
      debugPrint('TV HOME NETWORK LOAD ERROR: $error');
    }

    try {
      final fallback = await _repository.loadFallbackCache(
        platform: platform,
        selectedCategory: selectedCategory,
        pageSize: _pageSize,
      );
      if (!_active(token, requestKey)) return;
      if (fallback != null && fallback.items.isNotEmpty) {
        _loadingMode = 'errorWithOldData';
        _remember(requestKey, fallback);
        state = fallback;
        return;
      }
    } catch (error) {
      debugPrint('TV HOME FALLBACK CACHE ERROR: $error');
    }

    if (!_active(token, requestKey)) return;
    _showOffline(requestKey);
  }

  Future<void> retry() {
    return load(
      platform: _lastPlatform,
      selectedCategory: _lastCategory,
      clearPrevious: false,
    );
  }

  /// Append halaman berikutnya (dipicu scroll masuk zona lookahead).
  /// Guard: tidak ada request ganda, berhenti kalau server bilang habis.
  /// Gagal -> loadingMore dimatikan, hasMore dipertahankan supaya trigger
  /// berikutnya bisa retry. Fokus tidak terganggu: item lama tidak
  /// berubah posisi (merge append + key stabil di grid).
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final platform = _lastPlatform;
    final category = _lastCategory;
    final nextPage = state.page + 1;
    state = state.copyWith(loadingMore: true);
    try {
      final res = await _repository.loadNetworkPage(
        platform: platform,
        category: category,
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      if (platform != _lastPlatform || category != _lastCategory) return;
      if (res == null) {
        state = state.copyWith(loadingMore: false);
        return;
      }
      final merged = mergePagedItems(state.items, res.items);
      _repository.markOnline();
      state = state.copyWith(
        items: merged,
        page: nextPage,
        hasMore: res.hasMore,
        loadingMore: false,
        hasError: false,
      );
      if (_requestedKey != null) _remember(_requestedKey!, state);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  bool _active(int token, String requestKey) {
    return token == _loadToken && requestKey == _requestedKey;
  }

  void _remember(String displayedKey, TvHomeContentState next) {
    _displayedKey = displayedKey;
    _lastGoodState = next;
    _repository.saveRam(displayedKey, next);
  }

  void _showOffline(String requestKey) {
    _loadingMode = 'errorWithOldData';
    _repository.markOffline();

    if (state.items.isNotEmpty) {
      state = state.copyWith(
        loading: false,
        refreshing: false,
        hasError: true,
        offline: true,
      );
      return;
    }

    final last = _lastGoodState;
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

    _displayedKey = requestKey;
    state = const TvHomeContentState(
      loading: false,
      hasError: true,
      fromCache: false,
      offline: true,
    );
  }

  Future<void> _refreshInBackground(
    String platform,
    String selectedCategory,
    String requestKey,
    int token,
  ) async {
    try {
      final fresh = await _repository.refresh(
        platform,
        selectedCategory,
        pageSize: _pageSize,
      );
      if (!_active(token, requestKey)) return;

      if (fresh == null || fresh.items.isEmpty) {
        _loadingMode = 'errorWithOldData';
        final next = state.items.isNotEmpty
            ? state.copyWith(refreshing: false, hasError: true)
            : _lastGoodState?.copyWith(refreshing: false, hasError: true);
        if (next != null) {
          state = next;
        }
        return;
      }

      _loadingMode = 'loaded';
      _repository.markOnline();
      _remember(requestKey, fresh);
      state = fresh;
    } catch (error) {
      debugPrint('TV HOME BACKGROUND REFRESH ERROR: $error');
      if (!_active(token, requestKey)) return;
      _loadingMode = 'errorWithOldData';
      final next = state.items.isNotEmpty
          ? state.copyWith(refreshing: false, hasError: true)
          : _lastGoodState?.copyWith(refreshing: false, hasError: true);
      if (next == null) return;
      state = next;
    }
  }
}

final tvHomeContentProvider = StateNotifierProvider<TvHomeContentController, TvHomeContentState>(
  (ref) => TvHomeContentController(),
);
