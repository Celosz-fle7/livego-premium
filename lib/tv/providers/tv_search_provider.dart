import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/content/content_health_service.dart';
import '../cache/tv_ram_cache.dart';

class TvSearchState {
  final String query;
  final List<ContentItem> results;
  final bool loading;
  final bool hasError;

  /// Slug provider yang dipilih, null = Semua Source.
  final String? platform;

  const TvSearchState({
    this.query = '',
    this.results = const <ContentItem>[],
    this.loading = false,
    this.hasError = false,
    this.platform,
  });

  TvSearchState copyWith({String? query, List<ContentItem>? results, bool? loading, bool? hasError, String? platform, bool clearPlatform = false}) {
    return TvSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      loading: loading ?? this.loading,
      hasError: hasError ?? this.hasError,
      platform: clearPlatform ? null : (platform ?? this.platform),
    );
  }
}

class TvSearchController extends StateNotifier<TvSearchState> {
  static const Duration _searchTimeout = Duration(seconds: 9);

  TvSearchController() : super(const TvSearchState());

  int _ticket = 0;

  void setDraft(String value) {
    state = state.copyWith(query: value.trim(), hasError: false);
  }

  /// Ganti provider. Kalau ada query, cari ulang di provider itu.
  /// Filter di layar mengikuti provider ini (masing-masing sendiri).
  Future<void> setPlatform(String? slug) async {
    if (state.platform == slug) return;
    state = state.copyWith(platform: slug, clearPlatform: slug == null);
    if (state.query.isNotEmpty) {
      await search(state.query);
    } else {
      state = state.copyWith(results: const <ContentItem>[]);
    }
  }

  Future<void> search(String value) async {
    final clean = value.trim();
    final ticket = ++_ticket;
    if (clean.isEmpty) {
      // Clear hasil saja — pilihan provider tetap.
      state = state.copyWith(query: '', results: const <ContentItem>[], loading: false, hasError: false);
      return;
    }

    final platform = state.platform;
    final cacheKey = TvRamCache.key('search', [clean, platform ?? 'all']);
    final cached = TvRamCache.instance.read<List<ContentItem>>(cacheKey);
    if (cached != null) {
      state = TvSearchState(
        query: clean,
        loading: false,
        hasError: false,
        results: cached,
        platform: platform,
      );
      return;
    }

    // Search must never feel like it freezes the TV. Keep the old result list
    // while a new query is loading so remote focus has something stable to own.
    state = state.copyWith(query: clean, loading: true, hasError: false);
    List<ContentItem> rows = const <ContentItem>[];
    var hasError = false;
    try {
      rows = platform == null
          ? await LiveGoCatalog.searchAll(clean).timeout(_searchTimeout)
          : await LiveGoCatalog.search(clean, platform: platform).timeout(_searchTimeout);
    } catch (_) {
      hasError = true;
      rows = const <ContentItem>[];
    }
    if (ticket != _ticket) return;
    final cleanRows = ContentHealthService.filterPlayable(rows);
    if (cleanRows.isNotEmpty && !hasError) {
      TvRamCache.instance.write(cacheKey, cleanRows, ttl: TvRamCache.searchTtl);
    }
    state = TvSearchState(
      query: clean,
      loading: false,
      hasError: hasError,
      results: cleanRows,
      platform: platform,
    );
  }
}

final tvSearchProvider = StateNotifierProvider<TvSearchController, TvSearchState>(
  (ref) => TvSearchController(),
);
