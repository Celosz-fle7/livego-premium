import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/content/content_health_service.dart';

class TvSearchState {
  final String query;
  final List<ContentItem> results;
  final bool loading;
  final bool hasError;

  const TvSearchState({
    this.query = '',
    this.results = const <ContentItem>[],
    this.loading = false,
    this.hasError = false,
  });

  TvSearchState copyWith({String? query, List<ContentItem>? results, bool? loading, bool? hasError}) {
    return TvSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      loading: loading ?? this.loading,
      hasError: hasError ?? this.hasError,
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

  Future<void> search(String value) async {
    final clean = value.trim();
    final ticket = ++_ticket;
    if (clean.isEmpty) {
      state = const TvSearchState();
      return;
    }

    // Search must never feel like it freezes the TV. Keep the old result list
    // while a new query is loading so remote focus has something stable to own.
    state = state.copyWith(query: clean, loading: true, hasError: false);
    List<ContentItem> rows = const <ContentItem>[];
    var hasError = false;
    try {
      rows = await LiveGoCatalog.searchAll(clean).timeout(_searchTimeout);
    } catch (_) {
      hasError = true;
      rows = const <ContentItem>[];
    }
    if (ticket != _ticket) return;
    state = TvSearchState(
      query: clean,
      loading: false,
      hasError: hasError,
      results: ContentHealthService.filterPlayable(rows),
    );
  }
}

final tvSearchProvider = StateNotifierProvider<TvSearchController, TvSearchState>(
  (ref) => TvSearchController(),
);
